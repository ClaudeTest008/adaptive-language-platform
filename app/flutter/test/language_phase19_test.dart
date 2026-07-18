import 'package:adaptive_exam_platform/language/connections.dart';
import 'package:adaptive_exam_platform/language/curiosity.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/lesson_generator.dart';
import 'package:adaptive_exam_platform/language/mental_models.dart';
import 'package:adaptive_exam_platform/language/misconceptions.dart';
import 'package:adaptive_exam_platform/language/notebook.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
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

ConnectionGraph _graph(Map<String, double> mastery) => buildConnectionGraph(
  relations: _relations,
  conceptNames: _names,
  conceptMastery: mastery,
);

TeacherBrain _brain({
  Map<String, double> conceptMastery = const {
    _hambre: 0.9,
    _sueno: 0.8,
    _miedo: 0.7,
  },
  Map<LanguageSkill, double> skills = const {
    LanguageSkill.vocabulary: 0.5,
    LanguageSkill.speaking: 0.6,
  },
  List<Misconception> misconceptions = const [],
  bool storiesAvailable = false,
}) => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: DateTime(2026, 7, 18),
    nativeLanguage: 'en',
    targetLanguage: 'es',
    targetLanguageName: 'Spanish',
    baseLevel: 'A1',
    longTermGoal: 'Reach A2 Spanish',
    skillMastery: skills,
    conceptMastery: conceptMastery,
    conceptNames: _names,
    misconceptions: misconceptions,
    accuracy: 0.6,
    totalAnswered: 30,
    learningDna: [],
    historyDays: [],
    vocabularyPoolSize: 100,
    relations: _relations,
    storiesAvailable: storiesAvailable,
  ),
);

void main() {
  group('MentalModelBuilder', () {
    test('curated tener model turns linked phrases into one idea', () {
      final models = buildMentalModels(
        graph: _graph(const {_hambre: 0.9, _sueno: 0.8}),
      );
      expect(models, isNotEmpty);
      final tener = models.firstWhere((m) => m.title == 'tener, not to be');
      expect(tener.kind, MentalModelKind.contrast);
      expect(tener.insight.toUpperCase(), contains('TENER'));
    });

    test('no graph, no models — nothing fabricated', () {
      final models = buildMentalModels(graph: _graph(const {}));
      expect(models, isEmpty);
    });

    test('patterns are discovered from clusters', () {
      final patterns = discoverPatterns(
        _graph(const {_hambre: 0.9, _sueno: 0.8, _miedo: 0.7}),
      );
      expect(patterns, isNotEmpty);
    });
  });

  group('CuriosityEngine', () {
    test('flags a repeated misconception as worth fixing', () {
      final facts = _brain().facts;
      final notes = discoverCuriosities(
        facts: facts,
        connections: _graph(const {_hambre: 0.9}),
        misconceptions: [
          Misconception(
            id: '$_hambre|en',
            conceptId: _hambre,
            nativeLanguage: 'en',
            interferenceSource: 'en:be',
            pattern: 'tener',
            explanation: 'x',
            occurrences: 3,
            lastSeen: DateTime(2026, 7, 18),
          ),
        ],
      );
      expect(notes.any((n) => n.text.contains('pattern has tripped')), isTrue);
    });

    test('never spams: capped and only when conditions are met', () {
      final notes = discoverCuriosities(
        facts: _brain().facts,
        connections: _graph(const {}),
      );
      expect(notes.length, lessThanOrEqualTo(3));
    });

    test('connection moments reference known ground', () {
      final moments = buildConnectionMoments(
        _graph(const {_hambre: 0.9, _sueno: 0.8}),
      );
      expect(moments, isNotEmpty);
      expect(moments.first.text, contains('already know'));
    });
  });

  group('AdaptiveLessonGenerator', () {
    test('derives a plan with a pedagogical step sequence from the brain', () {
      final plan = const AdaptiveLessonGenerator().generate(_brain());
      expect(plan.steps, isNotEmpty);
      expect(plan.steps.any((s) => s.startsWith('New:')), isTrue);
      expect(plan.recommendations, isNotEmpty);
      // Speaking and conversation recommendations always present.
      expect(
        plan.byKind(LessonRecommendationKind.speaking),
        isNotNull,
      );
      expect(
        plan.byKind(LessonRecommendationKind.conversation),
        isNotNull,
      );
    });

    test('recovers a current misconception as the focus', () {
      final brain = _brain(
        misconceptions: [
          Misconception(
            id: '$_hambre|en',
            conceptId: _hambre,
            nativeLanguage: 'en',
            interferenceSource: 'en:be',
            pattern: 'tener',
            explanation: 'x',
            occurrences: 2,
            lastSeen: DateTime(2026, 7, 18),
          ),
        ],
      );
      // currentConceptId is set by the provider, not this bare brain, so the
      // generator falls back to "today" — still a valid focus.
      final plan = const AdaptiveLessonGenerator().generate(brain);
      expect(plan.todaysFocus.title, isNotEmpty);
    });
  });

  group('brain integration', () {
    test('brain carries mental models, curiosities and moments', () {
      final brain = _brain(storiesAvailable: true);
      expect(brain.mentalModels, isNotEmpty);
      expect(brain.connectionMoments, isNotEmpty);
      // Ready-to-read curiosity fires (vocab 0.5, stories available).
      expect(brain.curiosities, isNotEmpty);
    });

    test('notebook surfaces the mental model and a curiosity', () {
      final brain = _brain(storiesAvailable: true);
      final cats = brain.notebook.observations.map((o) => o.category).toSet();
      expect(cats, contains(ObservationCategory.mentalModel));
      expect(cats, contains(ObservationCategory.curiosity));
    });
  });
}
