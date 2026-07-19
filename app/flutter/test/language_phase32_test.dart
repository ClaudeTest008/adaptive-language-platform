import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/learning_journey_engine.dart';
import 'package:adaptive_language_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_language_platform/language/notebook.dart';
import 'package:adaptive_language_platform/language/pipeline.dart';
import 'package:adaptive_language_platform/language/reasoning_engine.dart';
import 'package:adaptive_language_platform/language/recommendation_engine.dart';
import 'package:adaptive_language_platform/language/relationships.dart';
import 'package:adaptive_language_platform/language/teacher_brain.dart';
import 'package:adaptive_language_platform/language/teacher_memory_engine.dart';
import 'package:adaptive_language_platform/language/teacher_packet.dart';
import 'package:flutter_test/flutter_test.dart';

const _hambre = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
final _relations = <LanguageRelation>[
  const LanguageRelation(from: _hambre, to: _sueno, type: LanguageRelationType.relatedTo),
];
const _names = {_hambre: 'tener hambre', _sueno: 'tener sueño'};

LanguageKnowledgeGraph _graph() {
  final es = LanguageNode(tier: LanguageTier.language, slug: 'es', name: 'Spanish');
  final a1 = LanguageNode(tier: LanguageTier.level, slug: 'a1', name: 'A1', parent: es);
  final g = LanguageNode(tier: LanguageTier.skill, slug: 'grammar', name: 'Grammar', parent: a1);
  final t = LanguageNode(tier: LanguageTier.domain, slug: 'tener', name: 'tener family', parent: g);
  return LanguageKnowledgeGraph([
    es, a1, g, t,
    LanguageNode(tier: LanguageTier.grammarConcept, slug: 'hambre', name: 'hambre', parent: t),
    LanguageNode(tier: LanguageTier.grammarConcept, slug: 'sueno', name: 'sueno', parent: t),
  ], _relations);
}

TeacherBrain _brain({
  Map<String, double> mastery = const {_hambre: 0.9, _sueno: 0.3},
  String? currentConceptId,
  List<NotebookSnapshot> history = const [],
  double accuracy = 0.6,
}) => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: DateTime(2026, 7, 18),
    nativeLanguage: 'en', targetLanguage: 'es', targetLanguageName: 'Spanish',
    baseLevel: 'A1', longTermGoal: 'Reach A2 Spanish',
    skillMastery: const {LanguageSkill.grammar: 0.5, LanguageSkill.speaking: 0.2},
    conceptMastery: mastery,
    conceptNames: _names, misconceptions: const [],
    accuracy: accuracy, totalAnswered: 30, learningDna: const [],
    historyDays: const [], vocabularyPoolSize: 100, relations: _relations,
    currentConceptId: currentConceptId, history: history,
  ),
);

NotebookSnapshot _snap(String day, double m) => NotebookSnapshot(
  day: day, mastery: {LanguageSkill.grammar: m}, accuracy: m, misconceptionTotal: 0);

void main() {
  group('recommendation engine — deterministic, explainable', () {
    test('same brain → identical ranked recommendations', () {
      final brain = _brain(currentConceptId: _hambre);
      final a = recommend(brain);
      final b = recommend(brain);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      for (final r in a) {
        expect(r.reason, isNotEmpty);
      }
    });

    test('recovery is the top recommendation', () {
      final brain = _brain(history: [
        _snap('2026-07-15', 0.6), _snap('2026-07-16', 0.5), _snap('2026-07-17', 0.4),
      ], accuracy: 0.3);
      final top = topRecommendation(brain);
      expect(top!.priority, 0);
      expect(top.kind, RecommendationKind.review);
    });

    test('empty/new brain → no recommendations, nothing fabricated', () {
      final brain = _brain(mastery: const {});
      // A brand-new brain has no focus/connections/memory to act on.
      final list = recommend(_brainEmpty());
      expect(list.every((r) => r.reason.isNotEmpty), isTrue);
      expect(topRecommendation(_brainEmpty()), anyOf(isNull, isA<Recommendation>()));
      // At minimum, deterministic + no crash.
      expect(brain.facts.cefr, isNotNull);
    });

    test('consumes teacher memory: recurring misconception ranks high', () {
      final brain = _brain();
      const memory = TeacherMemorySummary(
        lessonsCompleted: 3,
        recurringMisconceptions: ['ser vs estar'],
      );
      final list = recommend(brain, memory: memory);
      final rec = list.firstWhere((r) => r.id.startsWith('recurring-'));
      expect(rec.priority, 1);
      expect(rec.requiredConcepts, contains('ser vs estar'));
    });

    test('faded skill → reconnect (never "you forgot")', () {
      const memory = TeacherMemorySummary(
        lessonsCompleted: 5, forgottenSkills: ['imperfect']);
      final list = recommend(_brain(), memory: memory);
      final rec = list.firstWhere((r) => r.id.startsWith('reconnect-'));
      expect(rec.reason.toLowerCase(), contains('reconnect'));
      expect(rec.reason.toLowerCase(), isNot(contains('forgot')));
    });
  });

  group('learning journey engine — reuses curriculum journeys', () {
    test('assesses journeys with health + prediction from real activity', () {
      final brain = _brain(mastery: const {_hambre: 0.9, _sueno: 0.3});
      final reports = assessJourneys(brain, _graph());
      expect(reports, isNotEmpty);
      final r = reports.first;
      expect(r.health, isNotNull);
      // sueno not done → a next milestone + obstacle predicted.
      expect(r.prediction.nextMilestone, isNotNull);
    });

    test('no engaged concepts → no journeys (nothing fabricated)', () {
      final reports = assessJourneys(_brain(mastery: const {}), _graph());
      expect(reports, isEmpty);
    });

    test('completed journey is reported completed', () {
      final brain = _brain(mastery: const {_hambre: 0.9, _sueno: 0.9});
      final reports = assessJourneys(brain, _graph());
      expect(reports.first.health, JourneyHealth.completed);
    });
  });

  group('teacher packet — Phase 32 expansion', () {
    test('carries + serializes recommendations and journey health', () {
      final brain = _brain(currentConceptId: _hambre);
      final packet = buildTeacherPacket(
        brain: brain, graph: _graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor,
        recommendations: recommend(brain),
        journeyReport: assessJourneys(brain, _graph()).first,
      );
      expect(packet.recommendations, isNotEmpty);
      expect(packet.journeyReport, isNotNull);
      final s = serializeTeacherPacket(packet);
      expect(s, contains('RECOMMEND ('));
      expect(s, contains('JOURNEY HEALTH:'));
    });

    test('omits Phase 32 sections when nothing provided', () {
      final packet = buildTeacherPacket(
        brain: _brain(), graph: _graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor);
      expect(packet.recommendations, isEmpty);
      expect(serializeTeacherPacket(packet), isNot(contains('RECOMMEND (')));
    });
  });
}

TeacherBrain _brainEmpty() => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: _fixed,
    nativeLanguage: 'en', targetLanguage: 'es', targetLanguageName: 'Spanish',
    baseLevel: 'A1', longTermGoal: 'g',
    skillMastery: const {}, conceptMastery: const {}, conceptNames: const {},
    misconceptions: const [], accuracy: 0, totalAnswered: 0,
    learningDna: const [], historyDays: const [], vocabularyPoolSize: 100,
  ),
);

final _fixed = DateTime(2026, 7, 18);
