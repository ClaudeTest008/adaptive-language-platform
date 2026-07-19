import 'package:adaptive_language_platform/application/import_pipeline.dart';
import 'package:adaptive_language_platform/domain/models.dart';
import 'package:adaptive_language_platform/infrastructure/content_pack.dart';
import 'package:adaptive_language_platform/infrastructure/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

const _topics = [
  Topic(id: 'signs', name: 'Road Signs', order: 1),
  Topic(id: 'parking', name: 'Parking', order: 2),
];

ImportReport run(
  String content, {
  ImportFormat format = ImportFormat.csv,
  List<Question> existing = const [],
}) => runImportPipeline(
  content: content,
  format: format,
  examId: 'exam1',
  topics: _topics,
  existing: existing,
  author: 'tester@example.com',
);

void main() {
  const header =
      'question,answerA,answerB,answerC,answerD,correct,explanation,topic,difficulty,tags';

  group('CSV import', () {
    test('valid row imports as draft with mapped topic and tags', () {
      final report = run(
        '$header\n'
        '"What next?","Go","Stop",,,B,"Because stop.","road signs",easy,"a, b"',
      );
      expect(report.errors, isEmpty);
      expect(report.canImport, isTrue);
      final q = report.questions.single;
      expect(q.topicId, 'signs'); // mapped case-insensitively by name
      expect(q.correctIndex, 1);
      expect(q.answers, hasLength(2));
      expect(q.tags, ['a', 'b']);
      expect(q.status, ContentStatus.draft);
      expect(q.difficulty, Difficulty.easy);
      expect(q.author, 'tester@example.com');
    });

    test('quoted commas and escaped quotes parse correctly', () {
      final report = run(
        '$header\n'
        '"Signs, signals, and ""markings""?","A","B",,,A,"Fine.","signs",,',
      );
      expect(report.errors, isEmpty);
      expect(report.questions.single.text, 'Signs, signals, and "markings"?');
    });

    test('missing required column is a file-level error', () {
      final report = run(
        'question,answerA,answerB,correct,topic\n"q","a","b",A,"signs"',
      );
      expect(report.questions, isEmpty);
      expect(report.errors.single.message, contains('explanation'));
    });

    test(
      'blocking validations: missing pieces, bad correct, bad difficulty',
      () {
        final report = run(
          '$header\n'
          '"","A","B",,,E,"","nowhere",impossible,""',
        );
        final messages = report.errors.map((e) => e.message).join(' | ');
        expect(messages, contains('Missing question text'));
        expect(messages, contains('out of range'));
        expect(messages, contains('Missing explanation'));
        expect(messages, contains('Unknown topic'));
        expect(messages, contains('Invalid difficulty'));
        expect(report.canImport, isFalse);
      },
    );

    test('duplicate detection within batch and against existing', () {
      final existing = [demoQuestions.first]; // octagon question
      final report = run(
        '$header\n'
        '"${demoQuestions.first.text}","A","B",,,A,"x","signs",,\n'
        '"Fresh question one?","A","B",,,A,"x","signs",,\n'
        '"fresh   QUESTION one?","A","B",,,A,"x","signs",,',
        existing: existing,
      );
      final messages = report.errors.map((e) => e.message).join(' | ');
      expect(messages, contains('existing question'));
      expect(messages, contains('within this import'));
      expect(report.questions, hasLength(1)); // only the fresh one survives
      expect(report.canImport, isFalse); // blocking errors present
    });

    test('archived existing questions do not block re-import', () {
      final archived = demoQuestions.first.copyWith(
        status: ContentStatus.archived,
      );
      final report = run(
        '$header\n'
        '"${demoQuestions.first.text}","A","B",,,A,"x","signs",,',
        existing: [archived],
      );
      expect(report.errors, isEmpty);
    });
  });

  group('JSON import', () {
    test('array of objects imports; list tags supported', () {
      final report = run(
        '[{"question":"JSON q?","answerA":"A1","answerB":"B1",'
        '"correct":"A","explanation":"E","topic":"Parking",'
        '"tags":["x","y"],"difficulty":"hard"}]',
        format: ImportFormat.json,
      );
      expect(report.errors, isEmpty);
      final q = report.questions.single;
      expect(q.topicId, 'parking');
      expect(q.tags, ['x', 'y']);
      expect(q.difficulty, Difficulty.hard);
    });

    test('non-array JSON is a file-level error', () {
      final report = run('{"a":1}', format: ImportFormat.json);
      expect(report.questions, isEmpty);
      expect(report.errors.single.row, 0);
    });
  });

  group('content pack round-trip', () {
    test('encode then decode preserves exam, topics, questions', () {
      final json = encodeContentPack(
        exam: demoExam,
        topics: demoTopics,
        questions: demoQuestions.take(3).toList(),
      );
      final pack = decodeContentPack(json);
      expect(pack.exam.id, demoExam.id);
      expect(pack.exam.passThreshold, demoExam.passThreshold);
      expect(pack.topics, hasLength(demoTopics.length));
      expect(pack.questions, hasLength(3));
      expect(pack.questions.first.text, demoQuestions.first.text);
      expect(
        pack.questions.first.correctIndex,
        demoQuestions.first.correctIndex,
      );
    });

    test('foreign JSON rejected', () {
      expect(
        () => decodeContentPack('{"format":"other"}'),
        throwsFormatException,
      );
    });
  });
}
