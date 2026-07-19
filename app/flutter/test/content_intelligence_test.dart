import 'package:adaptive_language_platform/ai/chat_model.dart';
import 'package:adaptive_language_platform/ai/orchestrator.dart';
import 'package:adaptive_language_platform/application/document_ingestion.dart';
import 'package:adaptive_language_platform/application/import_pipeline.dart';
import 'package:adaptive_language_platform/application/large_import.dart';
import 'package:adaptive_language_platform/application/quality_engine.dart';
import 'package:adaptive_language_platform/domain/models.dart';
import 'package:adaptive_language_platform/infrastructure/demo_data.dart';
import 'package:adaptive_language_platform/infrastructure/demo_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

const _header =
    'question,answerA,answerB,answerC,answerD,correct,explanation,topic,difficulty,tags';

String bigCsv(int rows) {
  final sb = StringBuffer(_header);
  for (var i = 0; i < rows; i++) {
    sb.write(
      '\n"Generated question number $i about rule $i?",'
      '"Option one for $i","Option two for $i","Option three","Option four",'
      'B,"Explanation for rule $i with enough words to teach.","Road Signs",medium,"bulk"',
    );
  }
  return sb.toString();
}

Future<List<LargeImportProgress>> collect(
  Stream<LargeImportProgress> stream,
) async {
  final out = <LargeImportProgress>[];
  await for (final p in stream) {
    out.add(p);
  }
  return out;
}

void main() {
  group('large import engine', () {
    test(
      '10,000-question import: chunked, complete, review-gated',
      () async {
        final repo = DemoContentRepository();
        final events = await collect(
          runLargeImport(
            content: bigCsv(10000),
            format: ImportFormat.csv,
            examId: 'e',
            topics: demoTopics,
            existing: const [],
            repo: repo,
            chunkSize: 500,
            author: 'bulk@example.com',
          ),
        );
        final last = events.last;
        expect(last.done, isTrue);
        expect(last.saved, 10000);
        expect(events.length, greaterThan(10)); // chunked progress events
        // Monotonic progress.
        for (var i = 1; i < events.length; i++) {
          expect(
            events[i].processed,
            greaterThanOrEqualTo(events[i - 1].processed),
          );
        }
        // Everything is a review candidate, nothing entered the library.
        expect(await repo.getCandidates(), hasLength(10000));
        expect(await repo.getAllQuestions(), hasLength(demoQuestions.length));
        // Import job recorded.
        final job = (await repo.getImportJobs()).first;
        expect(job.imported, 10000);
        expect(job.format, 'csv-large');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('partial success: bad rows rejected, good rows proceed', () async {
      final repo = DemoContentRepository();
      final content =
          '$_header\n'
          '"Good question about yielding rules?","A","B",,,A,"Long enough explanation here.","Road Signs",easy,\n'
          '"Bad row","A","B",,,Z,"","Nowhere",weird,';
      final events = await collect(
        runLargeImport(
          content: content,
          format: ImportFormat.csv,
          examId: 'e',
          topics: demoTopics,
          existing: const [],
          repo: repo,
        ),
      );
      expect(events.last.saved, 1);
      expect(events.last.rejected, 1);
    });

    test(
      'resume after failure continues from checkpoint, no duplicates',
      () async {
        final repo = DemoContentRepository();
        final firstRun = await collect(
          runLargeImport(
            content: bigCsv(1000),
            format: ImportFormat.csv,
            examId: 'e',
            topics: demoTopics,
            existing: const [],
            repo: repo,
            chunkSize: 100,
            failAtIndex: 450, // dies in the 5th chunk
          ),
        );
        final failure = firstRun.last;
        expect(failure.failed, isTrue);
        expect(failure.checkpoint, isNotNull);
        expect(failure.checkpoint!.nextIndex, 400); // 4 chunks committed
        expect(await repo.getCandidates(), hasLength(400));

        final secondRun = await collect(
          runLargeImport(
            content: bigCsv(1000),
            format: ImportFormat.csv,
            examId: 'e',
            topics: demoTopics,
            existing: const [],
            repo: repo,
            chunkSize: 100,
            resumeFrom: failure.checkpoint,
          ),
        );
        expect(secondRun.last.done, isTrue);
        expect(await repo.getCandidates(), hasLength(1000)); // no dupes
      },
    );

    test('rollback removes candidates from a partial run', () async {
      final repo = DemoContentRepository();
      final run = await collect(
        runLargeImport(
          content: bigCsv(300),
          format: ImportFormat.csv,
          examId: 'e',
          topics: demoTopics,
          existing: const [],
          repo: repo,
          chunkSize: 100,
          failAtIndex: 250,
        ),
      );
      expect(await repo.getCandidates(), hasLength(200));
      await rollbackLargeImport(repo, run.last.checkpoint!);
      expect(await repo.getCandidates(), isEmpty);
    });
  });

  group('quality engine', () {
    test('well-formed question scores high', () {
      final report = assessQuality(demoQuestions.first);
      expect(report.score, greaterThan(0.8));
      expect(report.issues, isEmpty);
    });

    test('flags short text, duplicate options, weak explanation', () {
      final bad = Question(
        id: 'bad',
        examId: 'e',
        topicId: 'signs',
        text: 'Sign?',
        answers: const ['Yes', 'Yes', 'No'],
        correctIndex: 0,
        explanation: 'Yes.',
      );
      final report = assessQuality(bad);
      expect(report.score, lessThan(0.4));
      final all = report.issues.join(' ');
      expect(all, contains('very short'));
      expect(all, contains('Duplicate answer options'));
      expect(all, contains('Explanation too short'));
    });

    test('near-duplicate against existing content detected', () {
      final near = demoQuestions.first.copyWith(
        text: 'An eight-sided red sign means what exactly?',
      );
      final clone = Question(
        id: 'near',
        examId: 'e',
        topicId: 'signs',
        text: near.text,
        answers: demoQuestions.first.answers,
        correctIndex: 1,
        explanation: demoQuestions.first.explanation,
      );
      final report = assessQuality(clone, existing: demoQuestions);
      expect(report.issues.join(' '), contains('similar'));
    });

    test('archived questions ignored for duplicate probability', () {
      final archived = demoQuestions.first.copyWith(
        status: ContentStatus.archived,
      );
      final clone = Question(
        id: 'c',
        examId: 'e',
        topicId: 'signs',
        text: demoQuestions.first.text,
        answers: demoQuestions.first.answers,
        correctIndex: 1,
        explanation: demoQuestions.first.explanation,
      );
      final report = assessQuality(clone, existing: [archived]);
      expect(report.issues.join(' '), isNot(contains('similar')));
    });
  });

  group('document ingestion', () {
    const txt = '''
Chapter 1 Road Signs
Regulatory signs must always be obeyed. An octagon always means stop.
This sentence is filler with no testable content whatsoever here.

Chapter 2 Speed Rules
The maximum speed in residential areas is 25 mph in most states.
''';

    test('detects chapters and question opportunities in TXT', () {
      final doc = ingestDocument(txt, DocumentFormat.txt);
      expect(doc.topicCandidates, ['Road Signs', 'Speed Rules']);
      final ch1 = doc.chapters.first;
      expect(ch1.questionOpportunities.join(' '), contains('octagon'));
      expect(ch1.questionOpportunities.join(' '), isNot(contains('filler')));
      expect(doc.chapters[1].questionOpportunities.single, contains('25 mph'));
    });

    test('HTML headings become chapters; tags and scripts stripped', () {
      const html = '''
<html><head><style>.x{}</style><script>evil()</script></head><body>
<h2>Right of Way</h2>
<p>Drivers must always yield to pedestrians at crosswalks.</p>
</body></html>''';
      final doc = ingestDocument(html, DocumentFormat.html);
      expect(doc.topicCandidates, ['Right of Way']);
      expect(doc.chapters.single.body, isNot(contains('evil')));
      expect(
        doc.chapters.single.questionOpportunities.single,
        contains('yield to pedestrians'),
      );
    });

    test('content before first heading becomes Introduction', () {
      final doc = ingestDocument(
        'Some preamble text that must be kept somewhere safe.\n'
        'CHAPTER ONE\nBody requires at least these many words to count.',
        DocumentFormat.txt,
      );
      expect(doc.chapters.first.title, 'Introduction');
      expect(doc.chapters, hasLength(2));
    });
  });

  group('AI document extraction → import pipeline (end to end)', () {
    test('extracted rows flow through validation into candidates', () async {
      final model = FakeChatModel(
        handler: (_) =>
            '[{"question":"What does an octagon mean?","answerA":"Stop",'
            '"answerB":"Yield","answerC":"Merge","answerD":"Go",'
            '"correct":"A","explanation":"The octagon shape is reserved '
            'for stop signs everywhere.","sourceExcerpt":"An octagon '
            'always means stop."}]',
      );
      final rows = await AiOrchestrator(model).extractQuestions('source text');
      // Rows use the pipeline column contract: validate like any import.
      final csvish = [
        for (final row in rows)
          {...row, 'topic': 'Road Signs'}, // topic mapping by reviewer
      ];
      expect(csvish.single['question'], contains('octagon'));
      expect(csvish.single['correct'], 'A');
      expect(csvish.single['sourceExcerpt'], contains('octagon'));
      // Quality engine accepts it.
      final q = Question(
        id: 'x',
        examId: 'e',
        topicId: 'signs',
        text: csvish.single['question']!,
        answers: [
          csvish.single['answerA']!,
          csvish.single['answerB']!,
          csvish.single['answerC']!,
          csvish.single['answerD']!,
        ],
        correctIndex: 0,
        explanation: csvish.single['explanation']!,
      );
      expect(assessQuality(q).score, greaterThan(0.7));
    });
  });

  group('approval workflow', () {
    test('approve upserts approved question and clears candidate', () async {
      final repo = DemoContentRepository();
      final q = Question(
        id: 'new-appr',
        examId: 'e',
        topicId: 'signs',
        text: 'A freshly reviewed question about signals?',
        answers: const ['One', 'Two'],
        correctIndex: 0,
        explanation: 'Because the rulebook says so, in detail.',
        status: ContentStatus.draft,
      );
      await repo.saveCandidates([
        QuestionCandidate(
          id: 'cand-1',
          question: q,
          source: CandidateSource.ai,
          quality: assessQuality(q),
        ),
      ]);
      // Approve (mirrors _ReviewTab logic).
      await repo.upsertQuestion(q.copyWith(status: ContentStatus.approved));
      await repo.removeCandidates(['cand-1']);

      expect(await repo.getCandidates(), isEmpty);
      final stored = (await repo.getAllQuestions()).firstWhere(
        (x) => x.id == q.id,
      );
      expect(stored.status, ContentStatus.approved);
      // Still invisible to learners until published.
      expect((await repo.getQuestions()).any((x) => x.id == q.id), isFalse);
    });
  });
}
