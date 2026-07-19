import 'package:adaptive_language_platform/adaptive/codec.dart';
import 'package:adaptive_language_platform/adaptive/engine.dart';
import 'package:adaptive_language_platform/adaptive/model.dart';
import 'package:adaptive_language_platform/application/import_pipeline.dart';
import 'package:adaptive_language_platform/domain/models.dart';
import 'package:adaptive_language_platform/infrastructure/demo_data.dart';
import 'package:adaptive_language_platform/infrastructure/demo_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('question versioning', () {
    late DemoContentRepository repo;
    const id = 'q01';

    setUp(() => repo = DemoContentRepository());

    test('edits snapshot prior versions, newest first', () async {
      final original = demoQuestions.first;
      await repo.upsertQuestion(original.copyWith(text: 'Edit one'));
      await repo.upsertQuestion(
        (await repo.getAllQuestions())
            .firstWhere((q) => q.id == id)
            .copyWith(text: 'Edit two'),
      );
      final history = await repo.getVersionHistory(id);
      expect(history, hasLength(2));
      expect(history.first.text, 'Edit one'); // newest prior first
      expect(history.last.text, original.text);
      final current = (await repo.getAllQuestions()).firstWhere(
        (q) => q.id == id,
      );
      expect(current.version, 3);
      expect(current.text, 'Edit two');
    });

    test('rollback restores content as a NEW version', () async {
      final original = demoQuestions.first;
      await repo.upsertQuestion(original.copyWith(text: 'Changed'));
      await repo.rollbackQuestion(id, original.version);
      final current = (await repo.getAllQuestions()).firstWhere(
        (q) => q.id == id,
      );
      expect(current.text, original.text); // content restored
      expect(current.version, 3); // history never rewritten
      expect(await repo.getVersionHistory(id), hasLength(2));
    });

    test('rollback to unknown version throws', () async {
      expect(() => repo.rollbackQuestion(id, 99), throwsA(isA<StateError>()));
    });

    test('archive goes through versioning', () async {
      await repo.archiveQuestion(id);
      final history = await repo.getVersionHistory(id);
      expect(history, hasLength(1));
      expect(history.single.status, ContentStatus.published);
    });
  });

  group('workflow statuses', () {
    test(
      'learners see published only — review/approved/draft hidden',
      () async {
        final repo = DemoContentRepository();
        final q = demoQuestions.first;
        for (final status in [
          ContentStatus.draft,
          ContentStatus.review,
          ContentStatus.approved,
          ContentStatus.archived,
        ]) {
          await repo.upsertQuestion(q.copyWith(status: status));
          final learnerVisible = await repo.getQuestions();
          expect(
            learnerVisible.any((x) => x.id == q.id),
            isFalse,
            reason: status.name,
          );
        }
        await repo.upsertQuestion(q.copyWith(status: ContentStatus.published));
        expect((await repo.getQuestions()).any((x) => x.id == q.id), isTrue);
      },
    );
  });

  group('bulk operations', () {
    late DemoContentRepository repo;
    final ids = [demoQuestions[0].id, demoQuestions[1].id];

    setUp(() => repo = DemoContentRepository());

    test('bulkSetStatus versions each change and skips no-ops', () async {
      await repo.bulkSetStatus(ids, ContentStatus.archived);
      for (final id in ids) {
        final q = (await repo.getAllQuestions()).firstWhere((x) => x.id == id);
        expect(q.status, ContentStatus.archived);
        expect(q.version, 2);
      }
      // Repeat is a no-op: no new versions.
      await repo.bulkSetStatus(ids, ContentStatus.archived);
      expect(await repo.getVersionHistory(ids.first), hasLength(1));
    });

    test('bulkAddTag adds tag once', () async {
      await repo.bulkAddTag(ids, 'exam-2026');
      await repo.bulkAddTag(ids, 'exam-2026'); // idempotent
      for (final id in ids) {
        final q = (await repo.getAllQuestions()).firstWhere((x) => x.id == id);
        expect(q.tags.where((t) => t == 'exam-2026'), hasLength(1));
      }
    });
  });

  group('import jobs', () {
    test('recorded and returned newest first', () async {
      final repo = DemoContentRepository();
      ImportJob job(String id) => ImportJob(
        id: id,
        startedAt: DateTime(2026, 7, 9),
        format: 'csv',
        rowsTotal: 3,
        imported: 2,
        rejected: 1,
        duplicates: 1,
        durationMs: 5,
        author: 'a@b.c',
      );
      await repo.recordImportJob(job('one'));
      await repo.recordImportJob(job('two'));
      final jobs = await repo.getImportJobs();
      expect(jobs.map((j) => j.id).toList(), ['two', 'one']);
    });

    test('pipeline counts duplicates for analytics', () {
      final report = runImportPipeline(
        content:
            'question,answerA,answerB,correct,explanation,topic\n'
            '"${demoQuestions.first.text}","A","B",A,"x","Road Signs"\n'
            '"New q?","A","B",A,"x","Road Signs"\n'
            '"new  Q?","A","B",A,"x","Road Signs"',
        format: ImportFormat.csv,
        examId: 'e',
        topics: demoTopics,
        existing: demoQuestions,
      );
      expect(report.duplicateCount, 2);
    });
  });

  group('learner model codec (Firestore contract)', () {
    test('round-trip preserves the full model', () {
      const engine = LearnerEngine();
      var model = const LearnerModel();
      final now = DateTime(2026, 7, 9, 10);
      for (var i = 0; i < 5; i++) {
        model = engine.applyAnswer(
          model,
          AnswerEvent(
            questionId: 'q$i',
            conceptIds: ['signs', 'tag:basics'],
            correct: i.isEven,
            responseSeconds: 7.5,
            difficulty01: 0.5,
            answeredAt: now.add(Duration(minutes: i)),
          ),
        );
      }
      model = engine.recordMockExam(model, 0.8);

      final restored = learnerModelFromJson(learnerModelToJson(model));
      expect(restored.totalAnswered, model.totalAnswered);
      expect(restored.totalCorrect, model.totalCorrect);
      expect(restored.mockExamScores, model.mockExamScores);
      expect(restored.studyDays, model.studyDays);
      expect(restored.concepts.keys, model.concepts.keys);
      final a = model.concepts['signs']!;
      final b = restored.concepts['signs']!;
      expect(b.mastery, a.mastery);
      expect(b.streak, a.streak);
      expect(b.intervalDays, a.intervalDays);
      expect(b.nextReviewAt, a.nextReviewAt);
      expect(b.avgResponseSeconds, a.avgResponseSeconds);
    });

    test('empty and partial JSON decode with defaults', () {
      final m = learnerModelFromJson(const {});
      expect(m.totalAnswered, 0);
      expect(m.concepts, isEmpty);
    });
  });
}
