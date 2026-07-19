import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/misconceptions.dart';
import 'package:adaptive_language_platform/language/notebook.dart';
import 'package:adaptive_language_platform/language/reasoning_engine.dart';
import 'package:adaptive_language_platform/language/teacher_brain.dart';
import 'package:flutter_test/flutter_test.dart';

Misconception _misc(String conceptId, {int occurrences = 2}) => Misconception(
  id: '$conceptId|en:transfer',
  conceptId: conceptId,
  nativeLanguage: 'en',
  interferenceSource: 'en:be-adjective',
  pattern: 'tener + noun',
  explanation: 'English "to be" maps to Spanish "tener" here.',
  occurrences: occurrences,
  lastSeen: DateTime(2026, 7, 18),
);

BrainInputs _inputs({
  Map<LanguageSkill, double> skills = const {
    LanguageSkill.vocabulary: 0.5,
    LanguageSkill.grammar: 0.4,
    LanguageSkill.listening: 0.7,
    LanguageSkill.speaking: 0.4,
  },
  Map<String, double> conceptMastery = const {
    'es:a1:grammar:tener': 0.9,
    'es:a1:grammar:ser': 0.3,
    'es:a1:vocabulary:casa': 0.6,
  },
  List<Misconception> misconceptions = const [],
  NotebookSnapshot? previous,
  List<String> historyDays = const [],
  DateTime? today,
}) => BrainInputs(
  today: today ?? DateTime(2026, 7, 18),
  nativeLanguage: 'en',
  targetLanguage: 'es',
  targetLanguageName: 'Spanish',
  baseLevel: 'A1',
  longTermGoal: 'Reach A2 Spanish',
  skillMastery: skills,
  conceptMastery: conceptMastery,
  conceptNames: const {
    'es:a1:grammar:tener': 'tener for states',
    'es:a1:grammar:ser': 'ser vs estar',
  },
  misconceptions: misconceptions,
  accuracy: 0.6,
  totalAnswered: 30,
  learningDna: const ['audioLearner'],
  historyDays: historyDays,
  vocabularyPoolSize: 200,
  previous: previous,
);

void main() {
  const engine = OfflineReasoningEngine();

  test('assembles facts: skills carry level, confidence and a trend', () {
    final brain = engine.assemble(_inputs());
    final listening = brain.facts.skills[LanguageSkill.listening]!;
    expect(listening.level, 0.7);
    expect(listening.confidence, 0.7);
    // No previous snapshot → trend unknown.
    expect(listening.trend, Trend.unknown);
  });

  test('per-skill trend is improving when mastery rose since last session', () {
    final previous = NotebookSnapshot(
      day: '2026-07-17',
      mastery: const {LanguageSkill.speaking: 0.2},
      accuracy: 0.4,
      misconceptionTotal: 0,
    );
    final brain = engine.assemble(_inputs(previous: previous));
    expect(brain.facts.skills[LanguageSkill.speaking]!.trend, Trend.improving);
  });

  test('grammar buckets classify concept mastery correctly', () {
    final brain = engine.assemble(_inputs());
    final byId = {for (final g in brain.facts.grammar) g.conceptId: g};
    expect(byId['es:a1:grammar:tener']!.status, GrammarStatus.mastered);
    expect(byId['es:a1:grammar:ser']!.status, GrammarStatus.weak);
    // Vocabulary concept is not a grammar point.
    expect(byId.containsKey('es:a1:vocabulary:casa'), isFalse);
  });

  test('estimated vocabulary scales mastery by the pool size', () {
    final brain = engine.assemble(_inputs());
    // vocabulary mastery 0.5 × pool 200 = 100.
    expect(brain.identity.estimatedVocabulary, 100);
    expect(brain.facts.vocabulary.estimatedKnown, 100);
  });

  test('streak counts consecutive days ending today', () {
    final brain = engine.assemble(
      _inputs(
        today: DateTime(2026, 7, 18),
        historyDays: const ['2026-07-15', '2026-07-16', '2026-07-17'],
      ),
    );
    // 16,17,18 are consecutive up to today (18 implied); 15 breaks the chain
    // only if 16 missing — here 16,17,18 = 3, plus 15 adjacent to 16 = 4.
    expect(brain.identity.streakDays, 4);
  });

  test('streak breaks on a gap', () {
    final brain = engine.assemble(
      _inputs(
        today: DateTime(2026, 7, 18),
        historyDays: const ['2026-07-15', '2026-07-17'],
      ),
    );
    // Today 18 + 17 = 2, then 16 missing → stop.
    expect(brain.identity.streakDays, 2);
  });

  test('observations are explainable: trend note carries evidence', () {
    final previous = NotebookSnapshot(
      day: '2026-07-17',
      mastery: const {LanguageSkill.grammar: 0.1},
      accuracy: 0.3,
      misconceptionTotal: 0,
    );
    final brain = engine.assemble(_inputs(previous: previous));
    final trend = brain.notebook.observations.firstWhere(
      (o) => o.category == ObservationCategory.trend,
    );
    expect(trend.evidence, isNotEmpty);
    expect(trend.evidence.any((e) => e.delta != null), isTrue);
  });

  test('notebook still names the grammar misconception with a count', () {
    final brain = engine.assemble(
      _inputs(misconceptions: [_misc('es:a1:grammar:tener', occurrences: 3)]),
    );
    final grammar = brain.notebook.observations.firstWhere(
      (o) => o.category == ObservationCategory.grammar,
    );
    expect(grammar.text, contains('tener for states'));
    expect(grammar.text, contains('3×'));
    expect(grammar.evidence, isNotEmpty);
  });

  test('identity reflects languages and long-term goal', () {
    final brain = engine.assemble(_inputs());
    expect(brain.identity.targetLanguageName, 'Spanish');
    expect(brain.identity.nativeLanguage, 'en');
    expect(brain.objectives.longTerm, 'Reach A2 Spanish');
    expect(brain.learningDna, contains('audioLearner'));
  });
}
