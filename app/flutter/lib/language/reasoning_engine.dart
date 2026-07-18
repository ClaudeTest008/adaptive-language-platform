import 'connections.dart';
import 'curiosity.dart';
import 'entities.dart';
import 'mental_models.dart';
import 'misconceptions.dart';
import 'notebook.dart';
import 'relationships.dart';
import 'teacher_brain.dart';

/// Everything the reasoning engine needs to assemble a [TeacherBrain], gathered
/// from the app's authoritative sources by the provider layer. Keeping this as
/// a plain value object keeps the engine free of Flutter/Riverpod dependencies
/// and fully unit-testable.
class BrainInputs {
  const BrainInputs({
    required this.today,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.targetLanguageName,
    required this.baseLevel,
    required this.longTermGoal,
    required this.skillMastery,
    required this.conceptMastery,
    required this.conceptNames,
    required this.misconceptions,
    required this.accuracy,
    required this.totalAnswered,
    required this.learningDna,
    required this.historyDays,
    required this.vocabularyPoolSize,
    this.relations = const [],
    this.recentlyActivated = const {},
    this.storiesAvailable = false,
    this.pronunciationConfidence,
    this.listeningRecognition,
    this.conversationAbility,
    this.previous,
    this.currentObjective = 'Warm-up review',
    this.currentConceptId,
    this.secondaryObjective = 'Keep skills fresh',
    this.nextConceptName,
    this.interests = const [],
    this.lessonHistory = const [],
  });

  final DateTime today;
  final String nativeLanguage;
  final String targetLanguage;
  final String targetLanguageName;
  final String baseLevel;
  final String longTermGoal;
  final Map<LanguageSkill, double> skillMastery;
  final Map<String, double> conceptMastery;
  final Map<String, String> conceptNames;
  final List<Misconception> misconceptions;
  final double accuracy;
  final int totalAnswered;
  final List<String> learningDna;
  final List<String> historyDays;
  final int vocabularyPoolSize;

  /// Curriculum relations, for deriving the connection graph.
  final List<LanguageRelation> relations;

  /// Concepts touched in the current plan (marked as recently activated).
  final Set<String> recentlyActivated;

  /// Whether level-matched stories exist (gates the "ready to read" curiosity).
  final bool storiesAvailable;
  final double? pronunciationConfidence;
  final double? listeningRecognition;
  final double? conversationAbility;
  final NotebookSnapshot? previous;
  final String currentObjective;

  /// Concept id behind [currentObjective], so the teacher can focus on it.
  final String? currentConceptId;
  final String secondaryObjective;
  final String? nextConceptName;
  final List<Interest> interests;
  final List<LessonOutcome> lessonHistory;
}

/// The pluggable brain of the app. The offline implementation is deterministic
/// and needs no network; a premium implementation can replace only this,
/// leaving the model, persistence, and UI untouched.
abstract interface class ReasoningEngine {
  TeacherBrain assemble(BrainInputs inputs);
}

/// Deterministic, fully offline reasoning. Turns facts into a structured brain
/// and generates the notebook's observations from those same facts.
class OfflineReasoningEngine implements ReasoningEngine {
  const OfflineReasoningEngine();

  static const _trendThreshold = 0.03;

  @override
  TeacherBrain assemble(BrainInputs i) {
    final skills = _skills(i);
    final grammar = _grammar(i);
    final vocab = i.skillMastery[LanguageSkill.vocabulary] ?? 0;
    final cefr = estimateCefr(
      baseLevel: i.baseLevel,
      avgMastery: _avg(i.skillMastery.values),
    );

    final facts = LearnerFacts(
      skills: skills,
      grammar: grammar,
      vocabulary: VocabularySummary(
        mastery: vocab,
        estimatedKnown: (vocab * i.vocabularyPoolSize).round(),
      ),
      pronunciation: PronunciationState(
        confidence: i.pronunciationConfidence,
        trend: _skillTrend(i, LanguageSkill.pronunciation),
      ),
      accuracy: i.accuracy,
      totalAnswered: i.totalAnswered,
      cefr: cefr,
    );

    final connections = buildConnectionGraph(
      relations: i.relations,
      conceptNames: i.conceptNames,
      conceptMastery: i.conceptMastery,
      recentlyActivated: i.recentlyActivated,
    );
    final suggestion = connections.suggestions.isEmpty
        ? null
        : connections.suggestions.first;

    // Phase 19 derived layers: understanding, patterns, proactive teaching.
    final mentalModels = buildMentalModels(
      graph: connections,
      misconceptions: i.misconceptions,
    );
    final patterns = discoverPatterns(connections);
    final curiosities = discoverCuriosities(
      facts: facts,
      connections: connections,
      misconceptions: i.misconceptions,
      storiesAvailable: i.storiesAvailable,
    );
    final moments = buildConnectionMoments(connections);

    final notebook = buildTeacherNotebook(
      mastery: i.skillMastery,
      misconceptions: i.misconceptions,
      accuracy: i.accuracy,
      totalAnswered: i.totalAnswered,
      baseLevel: i.baseLevel,
      conceptNames: i.conceptNames,
      pronunciationConfidence: i.pronunciationConfidence,
      listeningRecognition: i.listeningRecognition,
      conversationAbility: i.conversationAbility,
      previous: i.previous,
      nextConceptName: i.nextConceptName,
      connectionSuggestion: suggestion,
    );

    // Surface the teacher's proactive teaching in the notebook itself: the top
    // mental model leads, the top curiosity closes — so the dashboard shows
    // "the teacher is teaching", not just measuring.
    final augmented = TeacherNotebook(
      cefrEstimate: notebook.cefrEstimate,
      observations: [
        if (mentalModels.isNotEmpty)
          TeacherObservation(
            mentalModels.first.insight,
            category: ObservationCategory.mentalModel,
            priority: 0,
            conceptIds: [
              mentalModels.first.anchorConceptId,
              ...mentalModels.first.relatedConceptIds,
            ],
          ),
        ...notebook.observations,
        if (curiosities.isNotEmpty)
          TeacherObservation(
            curiosities.first.text,
            category: ObservationCategory.curiosity,
            priority: 8,
            conceptIds: curiosities.first.conceptIds,
          ),
      ],
    );

    return TeacherBrain(
      identity: LearnerIdentity(
        nativeLanguage: i.nativeLanguage,
        targetLanguage: i.targetLanguage,
        targetLanguageName: i.targetLanguageName,
        currentLevel: cefr,
        longTermGoal: i.longTermGoal,
        streakDays: computeStreak(i.historyDays, i.today),
        estimatedVocabulary: (vocab * i.vocabularyPoolSize).round(),
      ),
      facts: facts,
      notebook: augmented,
      connections: connections,
      mentalModels: mentalModels,
      patterns: patterns,
      curiosities: curiosities,
      connectionMoments: moments,
      interests: i.interests,
      learningDna: i.learningDna,
      objectives: LearnerObjectives(
        current: i.currentObjective,
        secondary: i.secondaryObjective,
        longTerm: i.longTermGoal,
        currentConceptId: i.currentConceptId,
      ),
      lessonHistory: i.lessonHistory,
    );
  }

  Map<LanguageSkill, SkillState> _skills(BrainInputs i) => {
    for (final e in i.skillMastery.entries)
      e.key: SkillState(
        skill: e.key,
        level: e.value,
        // Mastery is an EWMA of correctness, so it doubles as the confidence
        // proxy until a distinct confidence signal is captured.
        confidence: e.value,
        trend: _skillTrend(i, e.key),
      ),
  };

  Trend _skillTrend(BrainInputs i, LanguageSkill skill) {
    final prev = i.previous?.mastery[skill];
    final now = i.skillMastery[skill];
    if (prev == null || now == null) return Trend.unknown;
    final delta = now - prev;
    if (delta > _trendThreshold) return Trend.improving;
    if (delta < -_trendThreshold) return Trend.declining;
    return Trend.stable;
  }

  /// Grammar buckets from concept-level mastery of grammar-tier concepts.
  List<GrammarPoint> _grammar(BrainInputs i) {
    final points = <GrammarPoint>[];
    for (final e in i.conceptMastery.entries) {
      if (!e.key.contains(':grammar:')) continue;
      points.add(
        GrammarPoint(
          conceptId: e.key,
          name: i.conceptNames[e.key] ?? e.key.split(':').last,
          status: _grammarStatus(e.value),
          confidence: e.value,
        ),
      );
    }
    points.sort((a, b) => b.confidence.compareTo(a.confidence));
    return points;
  }

  GrammarStatus _grammarStatus(double mastery) {
    if (mastery >= 0.8) return GrammarStatus.mastered;
    if (mastery >= 0.4) return GrammarStatus.learning;
    if (mastery > 0) return GrammarStatus.weak;
    return GrammarStatus.locked;
  }

  double _avg(Iterable<double> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
