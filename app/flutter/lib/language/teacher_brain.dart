import 'connections.dart';
import 'curiosity.dart';
import 'entities.dart';
import 'mental_models.dart';
import 'notebook.dart';

/// The Teacher Brain (Phase 17) — the application's single, structured source
/// of truth about the learner. It is a *derived* read-model: assembled by a
/// [ReasoningEngine] from the app's authoritative captures (learner model,
/// signals, misconceptions, Learning DNA, goals, persisted snapshots). It does
/// not store a parallel copy of that state, so there is exactly one truth and
/// many consumers (notebook, dashboard, AI teacher, reading, recommendations).
///
/// The model separates FACTS (objective, authoritative measurements) from
/// OBSERVATIONS (teacher interpretations generated from those facts, each
/// carrying its evidence). Sections that have no data source yet are typed but
/// empty, with a clear place to grow — never fabricated.

/// Direction of a metric over time. `unknown` until there is a prior session
/// to compare against.
enum Trend { improving, stable, declining, unknown }

/// Where a grammar point sits on the learning curve.
enum GrammarStatus { mastered, learning, weak, locked }

/// A single skill's objective state: how far along, how confident, and which
/// way it is trending. `level` and `confidence` are 0…1.
class SkillState {
  const SkillState({
    required this.skill,
    required this.level,
    required this.confidence,
    required this.trend,
  });

  final LanguageSkill skill;
  final double level;
  final double confidence;
  final Trend trend;
}

/// One grammar concept and how well the learner controls it.
class GrammarPoint {
  const GrammarPoint({
    required this.conceptId,
    required this.name,
    required this.status,
    required this.confidence,
  });

  final String conceptId;
  final String name;
  final GrammarStatus status;
  final double confidence;
}

/// Vocabulary facts. `mastery` is 0…1 against the current level;
/// `estimatedKnown` is a rough word count derived from it.
class VocabularySummary {
  const VocabularySummary({
    required this.mastery,
    required this.estimatedKnown,
  });

  final double mastery;
  final int estimatedKnown;
}

/// Pronunciation facts. `confidence` is null until a pronunciation exercise
/// has produced a score. Per-phoneme tracking (RR, LL, stress) grows here.
class PronunciationState {
  const PronunciationState({this.confidence, this.trend = Trend.unknown});

  final double? confidence;
  final Trend trend;
}

/// Why today's lesson exists — the teacher always knows the objective.
class LearnerObjectives {
  const LearnerObjectives({
    required this.current,
    required this.secondary,
    required this.longTerm,
    this.currentConceptId,
  });

  final String current;
  final String secondary;
  final String longTerm;

  /// The concept id behind [current] (a misconception or repair target), so
  /// the unified teacher can focus a session on it. Null when today's focus is
  /// general review.
  final String? currentConceptId;
}

/// The outcome of one completed lesson. Outcomes are stored — never the
/// conversation itself — so the teacher remembers progress without chat logs.
/// No producer records these yet (wired in later phases); the type exists so
/// the brain can grow into it without a migration.
class LessonOutcome {
  const LessonOutcome({
    required this.day,
    required this.objective,
    required this.score,
    required this.confidence,
    this.mistakes = const [],
    this.vocabularyGained = const [],
    this.grammarGained = const [],
    this.nextRecommendation,
  });

  final String day;
  final String objective;
  final double score;
  final double confidence;
  final List<String> mistakes;
  final List<String> vocabularyGained;
  final List<String> grammarGained;
  final String? nextRecommendation;
}

/// A topic the learner gravitates toward, with a 0…1 weight. Discovered from
/// activity in later phases; empty until then rather than guessed.
class Interest {
  const Interest(this.topic, this.weight);

  final String topic;
  final double weight;
}

/// Who the learner is right now: languages, working level, streak, and the
/// long-term goal driving the curriculum.
class LearnerIdentity {
  const LearnerIdentity({
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.targetLanguageName,
    required this.currentLevel,
    required this.longTermGoal,
    required this.streakDays,
    required this.estimatedVocabulary,
  });

  final String nativeLanguage;
  final String targetLanguage;
  final String targetLanguageName;
  final String currentLevel;
  final String longTermGoal;
  final int streakDays;
  final int estimatedVocabulary;
}

/// The objective, authoritative measurements — the ground truth from which all
/// observations are generated.
class LearnerFacts {
  const LearnerFacts({
    required this.skills,
    required this.grammar,
    required this.vocabulary,
    required this.pronunciation,
    required this.accuracy,
    required this.totalAnswered,
    required this.cefr,
  });

  final Map<LanguageSkill, SkillState> skills;
  final List<GrammarPoint> grammar;
  final VocabularySummary vocabulary;
  final PronunciationState pronunciation;
  final double accuracy;
  final int totalAnswered;
  final String cefr;
}

/// The assembled brain: identity, facts, the teacher's observations (notebook),
/// interests, Learning DNA, objectives, and lesson-outcome history. One object,
/// many consumers.
class TeacherBrain {
  const TeacherBrain({
    required this.identity,
    required this.facts,
    required this.notebook,
    this.connections = const ConnectionGraph(),
    this.mentalModels = const [],
    this.patterns = const [],
    this.curiosities = const [],
    this.connectionMoments = const [],
    this.interests = const [],
    this.learningDna = const [],
    required this.objectives,
    this.lessonHistory = const [],
  });

  final LearnerIdentity identity;
  final LearnerFacts facts;
  final TeacherNotebook notebook;

  /// The learner's derived relationship graph — how what they know connects,
  /// and which nearby concepts to teach next (Phase 18).
  final ConnectionGraph connections;

  /// Big-idea explanations that turn linked concepts into understanding
  /// (Phase 19).
  final List<MentalModel> mentalModels;

  /// Structural regularities discovered in the learner's graph (Phase 19).
  final List<LanguagePattern> patterns;

  /// Proactive teaching observations — the teacher noticing opportunities.
  final List<CuriosityNote> curiosities;

  /// Short "this connects to…" asides the tutor/reader can weave in.
  final List<ConnectionMoment> connectionMoments;
  final List<Interest> interests;
  final List<String> learningDna;
  final LearnerObjectives objectives;
  final List<LessonOutcome> lessonHistory;
}

/// Consecutive days of activity ending on [today]. Today counts as active —
/// the learner is here now — then it walks backward through the persisted
/// snapshot days while each prior day is present. Pure and testable.
int computeStreak(Iterable<String> days, DateTime today) {
  final set = days.toSet();
  var streak = 1;
  var cursor = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 1));
  while (set.contains(_iso(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
