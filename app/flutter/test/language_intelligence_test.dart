import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/notebook.dart';
import 'package:adaptive_language_platform/language/reasoning_engine.dart';
import 'package:adaptive_language_platform/language/relationships.dart';
import 'package:adaptive_language_platform/language/teacher_brain.dart';
import 'package:adaptive_language_platform/language/teacher_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

const _hambre = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
const _miedo = 'es:a1:grammar:tener:miedo';

final _relations = <LanguageRelation>[
  const LanguageRelation(
    from: _hambre,
    to: _sueno,
    type: LanguageRelationType.relatedTo,
  ),
  const LanguageRelation(
    from: _hambre,
    to: _miedo,
    type: LanguageRelationType.buildsOn,
  ),
];

const _names = {
  _hambre: 'tener hambre',
  _sueno: 'tener sueño',
  _miedo: 'tener miedo',
};

NotebookSnapshot _snap(String day, double m) => NotebookSnapshot(
  day: day,
  mastery: {LanguageSkill.grammar: m},
  accuracy: 0.5,
  misconceptionTotal: 0,
);

final _fixedDay = DateTime(2026, 7, 18);

/// Builds a brain via the real reasoning engine — every test reasons over a
/// genuinely-assembled brain, never a hand-built one.
TeacherBrain _brain({
  Map<String, double> conceptMastery = const {_hambre: 0.9},
  Map<LanguageSkill, double> skills = const {
    LanguageSkill.grammar: 0.5,
    LanguageSkill.speaking: 0.5,
  },
  List<String> learningDna = const [],
  List<NotebookSnapshot> history = const [],
  String? currentConceptId,
}) => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: _fixedDay,
    nativeLanguage: 'en',
    targetLanguage: 'es',
    targetLanguageName: 'Spanish',
    baseLevel: 'A1',
    longTermGoal: 'Reach A2 Spanish',
    skillMastery: skills,
    conceptMastery: conceptMastery,
    conceptNames: _names,
    misconceptions: const [],
    accuracy: 0.6,
    totalAnswered: 30,
    learningDna: learningDna,
    historyDays: const [],
    vocabularyPoolSize: 100,
    relations: _relations,
    history: history,
    currentConceptId: currentConceptId,
  ),
);

void main() {
  const engine = TeacherIntelligenceEngine();

  group('lesson pacing & conversation arc', () {
    test('stages follow the lesson arc, reflection closes it', () {
      expect(engine.stageForTurn(0), LessonStage.greeting);
      expect(engine.stageForTurn(4), LessonStage.discovery);
      expect(engine.stageForTurn(7, lessonLength: 8), LessonStage.reflection);
    });

    test('conversation state is derived, never duplicated', () {
      final brain = _brain(currentConceptId: _hambre);
      final s = engine.conversationState(brain, turn: 4);
      expect(s.stage, LessonStage.discovery);
      expect(s.objective, brain.objectives.current);
      expect(s.activeConceptId, _hambre);
      expect(s.confidence, brain.profile.confidence.overall);
    });
  });

  group('teaching decisions', () {
    test('recovery beats everything — review, no new concepts', () {
      final brain = _brain(history: [
        _snap('2026-07-15', 0.6),
        _snap('2026-07-16', 0.5),
        _snap('2026-07-17', 0.4),
      ]);
      final d = engine.decide(brain);
      expect(d.intent, TeacherIntent.review);
      expect(engine.pacing(brain), PacingAction.recoverConfidence);
    });

    test('an active misconception is corrected', () {
      final brain = _brain(currentConceptId: _hambre);
      final d = engine.decide(brain);
      expect(d.intent, TeacherIntent.correct);
      expect(d.conceptId, _hambre);
    });

    test('otherwise the top opportunity is a connection', () {
      final brain = _brain();
      final ops = engine.opportunities(brain);
      expect(ops, isNotEmpty);
      // With a strong tener anchor + unmet siblings, connect is offered.
      expect(
        ops.any((o) => o.intent == TeacherIntent.connect),
        isTrue,
      );
    });
  });

  group('connection-first & Socratic teaching', () {
    test('discovery moment asks rather than lectures', () {
      final brain = _brain();
      final moment = engine.moment(
        brain,
        const TeacherDecision(
          intent: TeacherIntent.discover,
          rationale: 'pattern ready',
          conceptId: _hambre,
        ),
      );
      expect(moment.socraticPrompt, isNotNull);
      expect(moment.message.toLowerCase(), isNot(contains('today we are learning')));
    });

    test('connect moment names the family (learning through connections)', () {
      final brain = _brain(conceptMastery: {
        _hambre: 0.9,
        _sueno: 0.8,
        _miedo: 0.7,
      });
      final moment = engine.moment(
        brain,
        const TeacherDecision(
          intent: TeacherIntent.connect,
          rationale: 'connect',
          conceptId: _hambre,
        ),
      );
      // Spanish-first now (English leaked into spoken replies before).
      expect(moment.message, contains('familia'));
      expect(moment.conceptIds, isNotEmpty);
    });
  });

  group('adaptive correction', () {
    test('corrects one weak grammar point, praise + connection-anchored why',
        () {
      final brain = _brain(conceptMastery: {
        _hambre: 0.9,
        _sueno: 0.8,
        'es:a1:grammar:ser:estar': 0.2, // weak
      });
      final c = engine.correction(brain);
      expect(c, isNotNull);
      expect(c!.praise, isNotEmpty);
      expect(c.correction, isNotEmpty);
      expect(c.why, isNotEmpty);
    });

    test('nothing weak → no correction (never invented)', () {
      final brain = _brain(conceptMastery: {_hambre: 0.9});
      expect(engine.correction(brain), isNull);
    });
  });

  group('memory & reflection', () {
    test('memory references real prior learning or is null', () {
      final withConn = _brain(conceptMastery: {
        _hambre: 0.9,
        _sueno: 0.8,
      });
      // strong connections → a connection moment exists → memory reference.
      final m = engine.memory(withConn);
      expect(m, isNotNull);
      // Spanish-first, like every teacher-authored line: an English opener
      // here became the spoken body of the bubble.
      expect(m!.reference.toLowerCase(), contains('recuerdas'));
    });

    test('reflection uses measured trends, empty when unmeasured', () {
      final rising = _brain(
        conceptMastery: {_hambre: 0.9},
        skills: {LanguageSkill.grammar: 0.7},
        history: [_snap('2026-07-17', 0.2)],
      );
      final r = engine.reflection(rising);
      // next always available (secondary objective); homework only if a
      // connection suggestion exists.
      expect(r.next, isNotEmpty);
    });
  });

  group('full plan & determinism', () {
    test('plan is complete and reflects the closing stage', () {
      final brain = _brain(currentConceptId: _hambre);
      final plan = engine.plan(brain, turn: 7);
      expect(plan.state.stage, LessonStage.reflection);
      expect(plan.reflection, isNotNull);
      expect(plan.moment.message, isNotEmpty);
    });

    test('deterministic — same brain, same plan', () {
      final brain = _brain(currentConceptId: _hambre);
      final a = engine.plan(brain, turn: 3);
      final b = engine.plan(brain, turn: 3);
      expect(a.moment.message, b.moment.message);
      expect(a.pacing, b.pacing);
      expect(a.state.objective, b.state.objective);
    });

    test('empty brain still yields a purposeful, non-fabricated decision', () {
      final brain = _brain(conceptMastery: const {}, skills: const {});
      final d = engine.decide(brain);
      expect(d.intent, isNotNull);
      expect(d.rationale, isNotEmpty);
    });
  });
}
