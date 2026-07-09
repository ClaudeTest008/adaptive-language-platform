/// Adaptive Learning Engine — learner model (ADR-0008).
/// Pure Dart: no Flutter, no Firebase. Concepts are identified by string
/// ids (topic ids, subtopics, tags — see graph.dart).
library;

/// One answered question, as seen by the engine.
class AnswerEvent {
  const AnswerEvent({
    required this.questionId,
    required this.conceptIds,
    required this.correct,
    required this.responseSeconds,
    required this.difficulty01,
    required this.answeredAt,
  });

  final String questionId;

  /// Concepts this question exercises (never empty; first = primary topic).
  final List<String> conceptIds;
  final bool correct;
  final double responseSeconds;

  /// Question difficulty mapped to 0 (easy) … 1 (hard).
  final double difficulty01;
  final DateTime answeredAt;
}

/// Per-concept mastery state. Immutable; engine produces updated copies.
class ConceptStats {
  const ConceptStats({
    required this.conceptId,
    this.attempts = 0,
    this.correct = 0,
    this.streak = 0,
    this.lapses = 0,
    this.mastery = 0,
    this.avgResponseSeconds = 0,
    this.intervalDays = 0,
    this.lastAnsweredAt,
    this.nextReviewAt,
  });

  final String conceptId;
  final int attempts;
  final int correct;

  /// Consecutive correct answers (resets on lapse).
  final int streak;

  /// Times a previously-correct concept was answered wrong.
  final int lapses;

  /// Exponentially weighted mastery estimate, 0..1.
  final double mastery;

  /// Exponentially weighted response time.
  final double avgResponseSeconds;

  /// Current spaced-repetition interval.
  final double intervalDays;
  final DateTime? lastAnsweredAt;
  final DateTime? nextReviewAt;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  bool isDue(DateTime now) =>
      nextReviewAt != null && !nextReviewAt!.isAfter(now);

  ConceptStats copyWith({
    int? attempts,
    int? correct,
    int? streak,
    int? lapses,
    double? mastery,
    double? avgResponseSeconds,
    double? intervalDays,
    DateTime? lastAnsweredAt,
    DateTime? nextReviewAt,
  }) => ConceptStats(
    conceptId: conceptId,
    attempts: attempts ?? this.attempts,
    correct: correct ?? this.correct,
    streak: streak ?? this.streak,
    lapses: lapses ?? this.lapses,
    mastery: mastery ?? this.mastery,
    avgResponseSeconds: avgResponseSeconds ?? this.avgResponseSeconds,
    intervalDays: intervalDays ?? this.intervalDays,
    lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
    nextReviewAt: nextReviewAt ?? this.nextReviewAt,
  );
}

/// Long-term learner traits ("Learning DNA"). Derived, never stored as
/// ground truth — recomputed from the model.
enum LearningTrait {
  fastResponder,
  slowButAccurate,
  lowConfidence,
  highConfidence,
  strugglesUnderTimePressure,
  repeatsMistakes,
  benefitsFromRepetition,
  consistent,
}

/// The complete learner model for one user + exam.
class LearnerModel {
  const LearnerModel({
    this.concepts = const {},
    this.totalAnswered = 0,
    this.totalCorrect = 0,
    this.mockExamScores = const [],
    this.studyDays = const {},
  });

  final Map<String, ConceptStats> concepts;
  final int totalAnswered;
  final int totalCorrect;

  /// Mock exam score fractions (0..1), oldest first.
  final List<double> mockExamScores;

  /// Days (yyyy-mm-dd) with at least one answer — study frequency.
  final Set<String> studyDays;

  double get overallAccuracy =>
      totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  LearnerModel copyWith({
    Map<String, ConceptStats>? concepts,
    int? totalAnswered,
    int? totalCorrect,
    List<double>? mockExamScores,
    Set<String>? studyDays,
  }) => LearnerModel(
    concepts: concepts ?? this.concepts,
    totalAnswered: totalAnswered ?? this.totalAnswered,
    totalCorrect: totalCorrect ?? this.totalCorrect,
    mockExamScores: mockExamScores ?? this.mockExamScores,
    studyDays: studyDays ?? this.studyDays,
  );
}

/// Exam readiness summary, recomputed after every session.
class ReadinessReport {
  const ReadinessReport({
    required this.readiness,
    required this.passProbability,
    required this.knowledgeCoverage,
    required this.retentionScore,
    required this.confidenceScore,
    required this.topicReadiness,
  });

  /// All values 0..1.
  final double readiness;
  final double passProbability;
  final double knowledgeCoverage;
  final double retentionScore;
  final double confidenceScore;
  final Map<String, double> topicReadiness;
}

/// One item in a generated study plan.
class StudyPlanItem {
  const StudyPlanItem({
    required this.conceptId,
    required this.reason,
    required this.suggestedQuestions,
  });

  final String conceptId;
  final String reason; // e.g. "due for review", "weak", "not seen yet"
  final int suggestedQuestions;
}

class StudyPlan {
  const StudyPlan({
    required this.items,
    required this.estimatedMinutes,
    required this.recommendMockExam,
    required this.dueReviewCount,
  });

  final List<StudyPlanItem> items;
  final int estimatedMinutes;
  final bool recommendMockExam;
  final int dueReviewCount;
}
