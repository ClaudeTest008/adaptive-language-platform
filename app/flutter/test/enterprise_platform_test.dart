import 'package:adaptive_exam_platform/adaptive/engine.dart';
import 'package:adaptive_exam_platform/adaptive/model.dart';
import 'package:adaptive_exam_platform/ai/chat_model.dart';
import 'package:adaptive_exam_platform/ai/orchestrator.dart';
import 'package:adaptive_exam_platform/application/import_pipeline.dart';
import 'package:adaptive_exam_platform/application/large_import.dart';
import 'package:adaptive_exam_platform/application/notification_service.dart';
import 'package:adaptive_exam_platform/application/search_service.dart';
import 'package:adaptive_exam_platform/domain/hierarchy.dart';
import 'package:adaptive_exam_platform/domain/models.dart';
import 'package:adaptive_exam_platform/domain/tenancy.dart';
import 'package:adaptive_exam_platform/infrastructure/demo_data.dart';
import 'package:adaptive_exam_platform/infrastructure/demo_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(
  String id,
  String text, {
  ContentStatus status = ContentStatus.published,
}) => Question(
  id: id,
  examId: 'e',
  topicId: 'signs',
  text: text,
  answers: const ['A', 'B'],
  correctIndex: 0,
  explanation: 'Because of the rulebook, in detail.',
  status: status,
);

void main() {
  group('content library inheritance (ADR-0012)', () {
    final libraries = {
      'global': ContentLibrary(
        id: 'global',
        name: 'Global Pack',
        scope: LibraryScope.global,
        questionsById: {
          'q1': q('q1', 'Global question one?'),
          'q2': q('q2', 'Global question two?'),
          'q3': q('q3', 'Global question three?'),
        },
      ),
      'us': ContentLibrary(
        id: 'us',
        name: 'US Country Pack',
        scope: LibraryScope.official,
        parentId: 'global',
        questionsById: {
          // Override q2 with a localized variant.
          'q2': q('q2', 'US-specific variant of question two?'),
          'q4': q('q4', 'US-only question four?'),
        },
      ),
      'acme': ContentLibrary(
        id: 'acme',
        name: 'Acme Driving School',
        scope: LibraryScope.organization,
        parentId: 'us',
        questionsById: {
          // Hide q3 for this org by archiving the inherited id.
          'q3': q(
            'q3',
            'Global question three?',
            status: ContentStatus.archived,
          ),
          'q5': q('q5', 'Acme private question five?'),
        },
      ),
    };

    test('child inherits parent chain without duplication', () {
      final resolved = resolveLibrary('acme', libraries);
      final ids = resolved.map((x) => x.id).toSet();
      expect(ids, {'q1', 'q2', 'q4', 'q5'}); // q3 hidden by override
    });

    test('nearest override wins', () {
      final resolved = resolveLibrary('acme', libraries);
      final q2 = resolved.firstWhere((x) => x.id == 'q2');
      expect(q2.text, contains('US-specific'));
    });

    test('parent library unaffected by child overrides (isolation)', () {
      final global = resolveLibrary('global', libraries);
      expect(global.map((x) => x.id).toSet(), {'q1', 'q2', 'q3'});
      expect(global.firstWhere((x) => x.id == 'q2').text, contains('Global'));
    });

    test('inheritance cycle throws instead of hanging', () {
      final cyclic = {
        'a': const ContentLibrary(
          id: 'a',
          name: 'A',
          scope: LibraryScope.global,
          parentId: 'b',
        ),
        'b': const ContentLibrary(
          id: 'b',
          name: 'B',
          scope: LibraryScope.organization,
          parentId: 'a',
        ),
      };
      expect(() => resolveLibrary('a', cyclic), throwsA(isA<StateError>()));
    });

    test('org roles map to capabilities', () {
      expect(
        const OrgMember(uid: 'u', role: OrgRole.editor).canEditContent,
        isTrue,
      );
      expect(
        const OrgMember(uid: 'u', role: OrgRole.editor).canManageMembers,
        isFalse,
      );
      expect(
        const OrgMember(uid: 'u', role: OrgRole.member).canEditContent,
        isFalse,
      );
      expect(
        const OrgMember(uid: 'u', role: OrgRole.owner).canManageMembers,
        isTrue,
      );
    });
  });

  group('curriculum hierarchy (ADR-0012)', () {
    const subject = CurriculumNode(
      level: CurriculumLevel.subject,
      slug: 'driving',
      name: 'Driving',
    );
    const chapter = CurriculumNode(
      level: CurriculumLevel.chapter,
      slug: 'signs',
      name: 'Road Signs',
      parent: subject,
    );
    const concept = CurriculumNode(
      level: CurriculumLevel.concept,
      slug: 'octagon',
      name: 'Stop Signs',
      parent: chapter,
      prerequisites: ['driving:signs:shapes'],
    );

    test('concept ids are hierarchical and stable', () {
      expect(concept.conceptId, 'driving:signs:octagon');
      expect(concept.lineageConceptIds, [
        'driving',
        'driving:signs',
        'driving:signs:octagon',
      ]);
    });

    test('levels may be skipped but never inverted', () {
      expect(validHierarchy(concept), isTrue); // subject→chapter→concept ok
      const inverted = CurriculumNode(
        level: CurriculumLevel.topic,
        slug: 'bad',
        name: 'Bad',
        parent: concept, // topic under concept = inversion
      );
      expect(validHierarchy(inverted), isFalse);
    });

    test('lineage concept ids feed the adaptive engine unchanged', () {
      const engine = LearnerEngine();
      var model = const LearnerModel();
      model = engine.applyAnswer(
        model,
        AnswerEvent(
          questionId: 'qx',
          conceptIds: concept.lineageConceptIds,
          correct: true,
          responseSeconds: 8,
          difficulty01: 0.5,
          answeredAt: DateTime(2026, 7, 9),
        ),
      );
      // One answer exercised the whole lineage — engine untouched.
      expect(
        model.concepts.keys,
        containsAll(['driving', 'driving:signs', 'driving:signs:octagon']),
      );
    });
  });

  group('search platform (ADR-0013)', () {
    final service = ClientSearchService(
      questions: demoQuestions.toList(),
      topics: demoTopics.toList(),
      importJobs: [
        ImportJob(
          id: 'j1',
          startedAt: DateTime(2026, 7, 9),
          format: 'csv',
          rowsTotal: 5,
          imported: 5,
          rejected: 0,
          duplicates: 0,
          durationMs: 3,
          author: 'importer@example.com',
        ),
      ],
    );

    test('ranks question-text hits above explanation hits', () async {
      // 'roundabout' is in q12's text; 'octagon' only in an explanation.
      final textHits = await service.search('roundabout');
      expect(textHits.first.score, 1.0);
      final explanationHits = await service.search('octagon');
      expect(explanationHits.first.score, 0.7);
      expect(explanationHits.first.entity, SearchEntity.question);
    });

    test('finds topics and import jobs', () async {
      final topicHits = await service.search('parking');
      expect(topicHits.any((h) => h.entity == SearchEntity.topic), isTrue);
      final jobHits = await service.search('importer@example.com');
      expect(jobHits.any((h) => h.entity == SearchEntity.importJob), isTrue);
    });

    test('similarity search surfaces near-duplicates', () async {
      final variant = q('v1', 'An eight-sided red sign means what?');
      final similar = await service.findSimilar(variant);
      expect(similar, isNotEmpty);
      expect(similar.first.id, demoQuestions.first.id);
    });
  });

  group('notification platform (ADR-0013)', () {
    test('derives notifications from adaptive outputs', () {
      final now = DateTime(2026, 7, 9, 8);
      final notifications = buildStudyNotifications(
        plan: const StudyPlan(
          items: [
            StudyPlanItem(
              conceptId: 'signs',
              reason: 'due for review',
              suggestedQuestions: 4,
            ),
          ],
          estimatedMinutes: 5,
          recommendMockExam: true,
          dueReviewCount: 1,
        ),
        readiness: const ReadinessReport(
          readiness: 0.82,
          passProbability: 0.7,
          knowledgeCoverage: 1,
          retentionScore: 0.9,
          confidenceScore: 0.8,
          topicReadiness: {},
        ),
        now: now,
      );
      expect(
        notifications.map((n) => n.kind),
        containsAll([
          NotificationKind.reviewDue,
          NotificationKind.adaptiveRecommendation,
        ]),
      );
      expect(notifications.first.body, contains('1 concept is'));
    });

    test('fan-out delivers to every channel; in-app inbox works', () async {
      final a = InAppNotificationChannel();
      final b = InAppNotificationChannel();
      final service = NotificationService([a, b]);
      await service.notify(
        AppNotification(
          kind: NotificationKind.importCompleted,
          title: 'Import done',
          body: '40 candidates queued.',
          createdAt: DateTime(2026, 7, 9),
        ),
      );
      expect(a.inbox, hasLength(1));
      expect(b.inbox, hasLength(1));
      expect(a.inbox.single.kind, NotificationKind.importCompleted);
    });
  });

  group('AI platform expansion (ADR-0013)', () {
    test('flashcards parse and ground in provided content', () async {
      final model = FakeChatModel(
        handler: (_) => '[{"front":"Octagon sign?","back":"Stop completely."}]',
      );
      final cards = await AiOrchestrator(
        model,
      ).generateFlashcards(demoQuestions.take(3).toList(), count: 1);
      expect(cards.single.front, contains('Octagon'));
      final prompt = model.calls.single.last.content;
      expect(prompt, contains(demoQuestions.first.text)); // grounding
    });

    test('improvement suggestions parse; bad output rejected', () async {
      final good = FakeChatModel(handler: (_) => '["Add context","Fix B"]');
      final suggestions = await AiOrchestrator(
        good,
      ).suggestImprovements(demoQuestions.first, const ['Question very short']);
      expect(suggestions, hasLength(2));

      final bad = FakeChatModel(handler: (_) => '"not a list"');
      expect(
        () => AiOrchestrator(
          bad,
        ).suggestImprovements(demoQuestions.first, const []),
        throwsFormatException,
      );
    });

    test('registry exposes new capabilities', () {
      final services = AiOrchestrator.services(FakeChatModel());
      expect(services.flashcardGenerator, isNotNull);
      expect(services.questionImprover, isNotNull);
      // Interfaces without orchestration remain null until implemented.
      expect(services.summarizer, isNull);
      expect(services.knowledgeGraphBuilder, isNull);
    });
  });

  group('100,000-question stress simulation', () {
    test(
      'large-import engine sustains 100k rows chunked',
      () async {
        final sb = StringBuffer(
          'question,answerA,answerB,correct,explanation,topic',
        );
        for (var i = 0; i < 100000; i++) {
          sb.write(
            '\n"Stress question $i about regulation $i?","Opt A$i","Opt B$i",A,'
            '"Explanation $i long enough to teach the rule.","Road Signs"',
          );
        }
        final repo = DemoContentRepository();
        var events = 0;
        LargeImportProgress? last;
        await for (final p in runLargeImport(
          content: sb.toString(),
          format: ImportFormat.csv,
          examId: 'e',
          topics: demoTopics,
          existing: const [],
          repo: repo,
          chunkSize: 5000,
        )) {
          events++;
          last = p;
        }
        expect(last!.done, isTrue);
        expect(last.saved, 100000);
        expect(events, greaterThan(20));
        expect(await repo.getCandidates(), hasLength(100000));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
