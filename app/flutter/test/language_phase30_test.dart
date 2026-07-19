import 'package:adaptive_exam_platform/language/conversation_continuity.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/experience.dart';
import 'package:adaptive_exam_platform/language/lesson_outcomes.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_exam_platform/language/notebook.dart';
import 'package:adaptive_exam_platform/language/pipeline.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/roleplay_engine.dart';
import 'package:adaptive_exam_platform/language/speaking_session.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/teacher_events.dart';
import 'package:adaptive_exam_platform/language/teacher_packet.dart';
import 'package:flutter_test/flutter_test.dart';

const _hambre = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
final _relations = <LanguageRelation>[
  const LanguageRelation(from: _hambre, to: _sueno, type: LanguageRelationType.relatedTo),
];
const _names = {_hambre: 'tener hambre', _sueno: 'tener sueño'};

TeacherBrain _brain({
  Map<String, double> mastery = const {_hambre: 0.9, _sueno: 0.8},
  String? currentConceptId,
}) {
  final b = const OfflineReasoningEngine().assemble(
    BrainInputs(
      today: DateTime(2026, 7, 18),
      nativeLanguage: 'en',
      targetLanguage: 'es',
      targetLanguageName: 'Spanish',
      baseLevel: 'A1',
      longTermGoal: 'Reach A2 Spanish',
      skillMastery: const {LanguageSkill.grammar: 0.6, LanguageSkill.speaking: 0.5},
      conceptMastery: mastery,
      conceptNames: _names,
      misconceptions: const [],
      accuracy: 0.6,
      totalAnswered: 30,
      learningDna: const [],
      historyDays: const [],
      vocabularyPoolSize: 100,
      relations: _relations,
      currentConceptId: currentConceptId,
    ),
  );
  return b;
}

SpeakingSession _speak(String target, String transcript, {String? conceptId}) =>
    analyzeSpeaking(target, transcript, conceptId: conceptId);

void main() {
  group('roleplay engine — deterministic selection & evolution', () {
    test('selects a scenario, deterministic, with an evolving 5-stage arc', () {
      final brain = _brain();
      final a = selectRoleplay(brain);
      final b = selectRoleplay(brain);
      expect(a.kind, b.kind);
      expect(a.stages.length, 5);
      expect(a.stages.map((s) => s.name),
          containsAllInOrder(['open', 'ask', 'handle-mistake']));
    });

    test('recovery mode → gentle conversation', () {
      // Sustained decline forces recovery mode in the brain.
      final brain = const OfflineReasoningEngine().assemble(
        BrainInputs(
          today: DateTime(2026, 7, 18),
          nativeLanguage: 'en', targetLanguage: 'es', targetLanguageName: 'Spanish',
          baseLevel: 'A1', longTermGoal: 'g',
          skillMastery: const {LanguageSkill.grammar: 0.5},
          conceptMastery: const {_hambre: 0.9},
          conceptNames: _names, misconceptions: const [],
          accuracy: 0.3, totalAnswered: 40, learningDna: const [],
          historyDays: const [], vocabularyPoolSize: 100, relations: _relations,
          history: [
            NotebookSnapshot(day: '2026-07-15', mastery: const {LanguageSkill.grammar: 0.6}, accuracy: 0.5, misconceptionTotal: 0),
            NotebookSnapshot(day: '2026-07-16', mastery: const {LanguageSkill.grammar: 0.5}, accuracy: 0.4, misconceptionTotal: 0),
            NotebookSnapshot(day: '2026-07-17', mastery: const {LanguageSkill.grammar: 0.4}, accuracy: 0.3, misconceptionTotal: 0),
          ],
        ),
      );
      final r = selectRoleplay(brain);
      expect(r.kind, RoleplayKind.conversation);
      expect(r.difficulty, RoleplayDifficulty.gentle);
    });

    test('resumes an interrupted roleplay from the continuation', () {
      final r = selectRoleplay(
        _brain(),
        continuation: const ConversationContinuation(
            opener: 'hotel scene', thread: 'roleplay'),
      );
      expect(r.resumed, isTrue);
    });

    test('advance progresses stages then completes', () {
      var p = RoleplayProgress(scenario: selectRoleplay(_brain()));
      expect(p.currentStage!.name, 'open');
      for (var i = 0; i < 5; i++) {
        p = advanceRoleplay(p);
      }
      expect(p.done, isTrue);
      expect(completeRoleplay(p).success, isTrue);
    });

    test('feedback advances only on a solid attempt', () {
      final p = RoleplayProgress(scenario: selectRoleplay(_brain()));
      expect(roleplayFeedback(p, _speak('hola', 'hola')).advance, isTrue);
      expect(roleplayFeedback(p, _speak('hola', '')).advance, isFalse);
    });
  });

  group('lesson outcomes — measured evidence only', () {
    test('builds a result + typed events from speaking/reading', () {
      final brain = _brain();
      final result = buildLessonResult(
        brain: brain,
        day: '2026-07-18',
        objective: 'tener family',
        speaking: [
          _speak('tener hambre', 'tener hambre', conceptId: _hambre),
        ],
        reading: const [
          ReadingRecord(day: '2026-07-18', storyId: 's', title: 'Viaje',
              topics: ['travel'], knownRatio: 0.8, unknownWords: []),
        ],
      );
      expect(result.speakingScore, isNotNull);
      expect(result.readingKnownRatio, 0.8);
      expect(result.events.whereType<LessonFinished>(), isNotEmpty);
      expect(result.events.whereType<ReadingCompleted>(), isNotEmpty);
      // The compact outcome feeds the brain.
      expect(result.toOutcome().objective, contains('tener family'));
    });

    test('empty lesson → empty result, nothing fabricated', () {
      final result = buildLessonResult(
        brain: _brain(mastery: const {}), day: '2026-07-18', objective: 'x');
      expect(result.speakingScore, isNull);
      expect(result.readingKnownRatio, isNull);
    });

    test('reflection producer draws only from the result', () {
      final brain = _brain();
      final result = buildLessonResult(
        brain: brain, day: '2026-07-18', objective: 'tener',
        speaking: [_speak('tener hambre', 'tener hambre', conceptId: _hambre)],
      );
      final reflection = reflectFromLesson(result);
      expect(reflection.day, '2026-07-18');
      expect(reflection.nextAdjustment, isNotNull);
    });

    test('event JSON serializes typed kind', () {
      const e = SpeakingImproved(day: '2026-07-18', evidence: 'pron 90%');
      expect(e.toJson()['kind'], 'speakingImproved');
      expect(e.kind, TeacherEventKind.speakingImproved);
    });
  });

  group('teacher packet expansion (Phase 30)', () {
    LanguageKnowledgeGraph graph() => LanguageKnowledgeGraph([
      LanguageNode(tier: LanguageTier.language, slug: 'es', name: 'Spanish'),
    ], _relations);

    test('packet carries roleplay + last lesson + reflection + events', () {
      final brain = _brain(currentConceptId: _hambre);
      final result = buildLessonResult(
        brain: brain, day: '2026-07-18', objective: 'tener',
        speaking: [_speak('tener hambre', 'tener hambre', conceptId: _hambre)]);
      final packet = buildTeacherPacket(
        brain: brain, graph: graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor,
        roleplay: selectRoleplay(brain),
        lastLesson: result,
        reflection: reflectFromLesson(result),
      );
      expect(packet.roleplay, isNotNull);
      expect(packet.lessonOutcomeSummary, isNotNull);
      expect(packet.recentEvents, isNotEmpty);
      final s = serializeTeacherPacket(packet);
      expect(s, contains('ROLEPLAY:'));
      expect(s, contains('LAST LESSON:'));
      expect(s, contains('EVENT:'));
    });

    test('packet omits Phase 30 sections when nothing is provided', () {
      final packet = buildTeacherPacket(
        brain: _brain(), graph: graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor);
      expect(packet.roleplay, isNull);
      expect(serializeTeacherPacket(packet), isNot(contains('ROLEPLAY:')));
    });
  });
}
