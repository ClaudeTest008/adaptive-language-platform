import 'package:adaptive_exam_platform/infrastructure/prefs_teacher_memory_repository.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/lesson_outcomes.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_exam_platform/language/pipeline.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/roleplay_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/speaking_session.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/teacher_memory.dart';
import 'package:adaptive_exam_platform/language/teacher_memory_engine.dart';
import 'package:adaptive_exam_platform/language/teacher_packet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hambre = 'es:a1:grammar:tener:hambre';
final _relations = <LanguageRelation>[
  const LanguageRelation(from: _hambre, to: 'es:a1:grammar:tener:sueno',
      type: LanguageRelationType.relatedTo),
];
const _names = {_hambre: 'tener hambre'};

TeacherBrain _brain() => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: DateTime(2026, 7, 18),
    nativeLanguage: 'en', targetLanguage: 'es', targetLanguageName: 'Spanish',
    baseLevel: 'A1', longTermGoal: 'Reach A2 Spanish',
    skillMastery: const {LanguageSkill.grammar: 0.6},
    conceptMastery: const {_hambre: 0.9},
    conceptNames: _names, misconceptions: const [],
    accuracy: 0.6, totalAnswered: 30, learningDna: const [],
    historyDays: const [], vocabularyPoolSize: 100, relations: _relations,
  ),
);

CompletedLesson _lesson(String day, {
  double score = 0.8,
  List<String> mastered = const [],
  List<String> struggled = const [],
}) => CompletedLesson(
  day: day, objective: 'lesson $day', speakingScore: score,
  conceptsMastered: mastered, conceptsStruggled: struggled,
  eventKinds: const ['lessonFinished'],
);

void main() {
  group('persistence + restart restoration', () {
    test('prefs repository persists lessons across a fresh instance', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsTeacherMemoryRepository();
      await repo.appendLesson(_lesson('2026-07-17', mastered: ['tener hambre']));
      await repo.appendLesson(_lesson('2026-07-18'));

      final fresh = PrefsTeacherMemoryRepository(); // simulated restart
      final loaded = await fresh.loadLessons();
      expect(loaded, hasLength(2));
      expect(loaded.first.conceptsMastered, contains('tener hambre'));
    });

    test('same day+objective merges (no duplicate)', () async {
      final repo = InMemoryTeacherMemoryRepository();
      await repo.appendLesson(_lesson('2026-07-18', score: 0.5));
      await repo.appendLesson(_lesson('2026-07-18', score: 0.9));
      final loaded = await repo.loadLessons();
      expect(loaded, hasLength(1));
      expect(loaded.single.speakingScore, 0.9);
    });

    test('roleplay position persists and clears', () async {
      final repo = InMemoryTeacherMemoryRepository();
      expect(await repo.loadRoleplay(), isNull);
      await repo.saveRoleplay(const RoleplayMemory(
        title: 'Hotel', kind: RoleplayKind.hotel, stageIndex: 2,
        done: false, day: '2026-07-18'));
      expect((await repo.loadRoleplay())!.stageIndex, 2);
      await repo.saveRoleplay(null);
      expect(await repo.loadRoleplay(), isNull);
    });
  });

  group('lesson-end pipeline (engines connected)', () {
    test('a session becomes a persistable completed lesson', () {
      final brain = _brain();
      final result = buildLessonResult(
        brain: brain, day: '2026-07-18', objective: 'tener',
        speaking: [analyzeSpeaking('tener hambre', 'tener hambre', conceptId: _hambre)]);
      final lesson = completedFromResult(result, reflection: reflectFromLesson(result));
      expect(lesson.objective, 'tener');
      expect(lesson.speakingScore, isNotNull);
      expect(lesson.toOutcome().objective, 'tener');
      // JSON round-trips (persistence).
      final back = CompletedLesson.fromJson(lesson.toJson());
      expect(back.day, lesson.day);
      expect(back.speakingScore, lesson.speakingScore);
    });
  });

  group('long-term memory engine', () {
    test('empty history → empty summary, nothing fabricated', () {
      final s = summarizeMemory(
        brain: _brain(), lessons: const [], today: '2026-07-18');
      expect(s.isEmpty, isTrue);
      expect(s.longTermStrengths, isEmpty);
      expect(s.forgottenSkills, isEmpty);
    });

    test('recurring strengths, weaknesses and recovery are measured', () {
      final lessons = [
        _lesson('2026-07-10', mastered: ['present'], struggled: ['subjunctive']),
        _lesson('2026-07-12', mastered: ['present'], struggled: ['subjunctive']),
        _lesson('2026-07-16', mastered: ['subjunctive']), // recovered
      ];
      final s = summarizeMemory(
        brain: _brain(), lessons: lessons, today: '2026-07-18');
      expect(s.longTermStrengths, contains('present'));
      expect(s.recurringMisconceptions, contains('subjunctive'));
      expect(s.recoveredSkills, contains('subjunctive'));
      expect(s.lessonsCompleted, 3);
    });

    test('confidence trend improves when scores rise', () {
      final lessons = [
        _lesson('2026-07-10', score: 0.3),
        _lesson('2026-07-12', score: 0.4),
        _lesson('2026-07-16', score: 0.8),
        _lesson('2026-07-17', score: 0.9),
      ];
      final s = summarizeMemory(
        brain: _brain(), lessons: lessons, today: '2026-07-18');
      expect(s.confidenceTrend, MemoryTrend.improving);
      expect(s.learningMomentum, greaterThan(0));
    });
  });

  group('forgetting & reinforcement (deterministic)', () {
    test('faded concept decays; strongly-mastered stays stable', () {
      final lessons = [
        // "old" mastered once, long ago → decays.
        _lesson('2026-06-01', mastered: ['old']),
        // "strong" mastered 3× recently → stable, never decays.
        _lesson('2026-07-10', mastered: ['strong']),
        _lesson('2026-07-14', mastered: ['strong']),
        _lesson('2026-07-17', mastered: ['strong']),
      ];
      final decayed = decayedConcepts(lessons, today: '2026-07-18');
      expect(decayed, contains('old'));
      expect(decayed, isNot(contains('strong')));
    });

    test('recent practice never decays', () {
      final decayed = decayedConcepts(
        [_lesson('2026-07-17', mastered: ['fresh'])], today: '2026-07-18');
      expect(decayed, isEmpty);
    });
  });

  group('teacher packet — memory expansion', () {
    LanguageKnowledgeGraph graph() => LanguageKnowledgeGraph([
      LanguageNode(tier: LanguageTier.language, slug: 'es', name: 'Spanish'),
    ], _relations);

    test('packet carries + serializes the memory summary when present', () {
      final brain = _brain();
      final summary = summarizeMemory(brain: brain, lessons: [
        _lesson('2026-07-16', mastered: ['present']),
        _lesson('2026-07-17', mastered: ['present']),
      ], today: '2026-07-18');
      final packet = buildTeacherPacket(
        brain: brain, graph: graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor,
        memory: summary);
      expect(packet.memory, isNotNull);
      expect(serializeTeacherPacket(packet), contains('MEMORY:'));
    });

    test('empty memory is omitted from the packet', () {
      final packet = buildTeacherPacket(
        brain: _brain(), graph: graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor,
        memory: summarizeMemory(
          brain: _brain(), lessons: const [], today: '2026-07-18'));
      expect(packet.memory, isNull);
      expect(serializeTeacherPacket(packet), isNot(contains('MEMORY:')));
    });
  });
}
