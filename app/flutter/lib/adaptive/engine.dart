/// Adaptive Learning Engine core (ADR-0008). Pure functions over the
/// learner model: answer application, confidence, readiness, study plans,
/// learning DNA. Deterministic and unit-tested; no Flutter, no I/O.
library;

import 'dart:math';

import 'graph.dart';
import 'model.dart';
import 'scheduler.dart';

/// Mastery learning rate: how strongly one answer moves the estimate.
const _masteryAlpha = 0.3;

/// Reduced-strength update applied to graph-related concepts on a lapse.
const _propagationFactor = 0.3;

class LearnerEngine {
  const LearnerEngine({
    this.scheduler = const ExpandingIntervalScheduler(),
    this.graph = const KnowledgeGraph({}),
  });

  final ReviewScheduler scheduler;
  final KnowledgeGraph graph;

  // ------------------------------------------------------------- updates

  /// Applies one answer to the model: every referenced concept updates,
  /// incorrect answers additionally reinforce graph-related concepts at
  /// reduced strength.
  LearnerModel applyAnswer(LearnerModel model, AnswerEvent event) {
    final concepts = Map<String, ConceptStats>.of(model.concepts);

    for (final conceptId in event.conceptIds) {
      concepts[conceptId] = _updateConcept(
        concepts[conceptId] ?? ConceptStats(conceptId: conceptId),
        event,
        full: true,
      );
    }
    if (!event.correct) {
      final direct = event.conceptIds.toSet();
      for (final relatedId in graph.relatedTo(event.conceptIds.first)) {
        if (direct.contains(relatedId)) continue;
        final existing = concepts[relatedId];
        if (existing == null || existing.attempts == 0) continue;
        concepts[relatedId] = existing.copyWith(
          mastery: _ewma(
            existing.mastery,
            0,
            _masteryAlpha * _propagationFactor,
          ),
        );
      }
    }

    final day =
        '${event.answeredAt.year}-${event.answeredAt.month}-${event.answeredAt.day}';
    return model.copyWith(
      concepts: concepts,
      totalAnswered: model.totalAnswered + 1,
      totalCorrect: model.totalCorrect + (event.correct ? 1 : 0),
      studyDays: {...model.studyDays, day},
    );
  }

  LearnerModel recordMockExam(LearnerModel model, double scoreFraction) =>
      model.copyWith(mockExamScores: [...model.mockExamScores, scoreFraction]);

  ConceptStats _updateConcept(
    ConceptStats stats,
    AnswerEvent event, {
    required bool full,
  }) {
    final wasEstablished = stats.mastery >= 0.6;
    final schedule = scheduler.schedule(
      stats: stats,
      correct: event.correct,
      now: event.answeredAt,
    );
    return stats.copyWith(
      attempts: stats.attempts + 1,
      correct: stats.correct + (event.correct ? 1 : 0),
      streak: event.correct ? stats.streak + 1 : 0,
      lapses: stats.lapses + (!event.correct && wasEstablished ? 1 : 0),
      mastery: _ewma(stats.mastery, event.correct ? 1 : 0, _masteryAlpha),
      avgResponseSeconds: stats.attempts == 0
          ? event.responseSeconds
          : _ewma(stats.avgResponseSeconds, event.responseSeconds, 0.3),
      intervalDays: schedule.intervalDays,
      lastAnsweredAt: event.answeredAt,
      nextReviewAt: schedule.nextReviewAt,
    );
  }

  // ---------------------------------------------------------- confidence

  /// Confidence in a concept, 0..1: mastery anchored, adjusted by streak
  /// consistency, response speed, and evidence volume. Correctness alone
  /// is deliberately insufficient (spec: confidence model).
  double conceptConfidence(ConceptStats s, {double expectedSeconds = 15}) {
    if (s.attempts == 0) return 0;
    final streakFactor = min(s.streak, 5) / 5;
    final speedFactor = s.avgResponseSeconds <= 0
        ? 0.5
        : (expectedSeconds / max(s.avgResponseSeconds, 1)).clamp(0.0, 1.0);
    final evidence = min(s.attempts, 8) / 8;
    final lapsePenalty = s.attempts == 0 ? 0 : min(s.lapses / s.attempts, 0.5);
    final raw =
        0.5 * s.mastery +
        0.2 * streakFactor +
        0.15 * speedFactor +
        0.15 * s.accuracy;
    return ((raw - 0.3 * lapsePenalty) * (0.5 + 0.5 * evidence)).clamp(
      0.0,
      1.0,
    );
  }

  // ----------------------------------------------------------- readiness

  /// Readiness over topic concepts only (primary curriculum units).
  /// ponytail: pass probability is a logistic heuristic over readiness vs
  /// pass ratio; upgrade path is calibration against real outcome data.
  ReadinessReport readiness(
    LearnerModel model, {
    required List<String> allTopicIds,
    required double passRatio,
    required DateTime now,
  }) {
    if (allTopicIds.isEmpty) {
      return const ReadinessReport(
        readiness: 0,
        passProbability: 0,
        knowledgeCoverage: 0,
        retentionScore: 0,
        confidenceScore: 0,
        topicReadiness: {},
      );
    }
    final topicReadiness = <String, double>{};
    var covered = 0, confidenceSum = 0.0, overdue = 0, scheduled = 0;
    for (final id in allTopicIds) {
      final s = model.concepts[id];
      if (s == null || s.attempts == 0) {
        topicReadiness[id] = 0;
        continue;
      }
      covered++;
      final confidence = conceptConfidence(s);
      confidenceSum += confidence;
      topicReadiness[id] = (0.7 * s.mastery + 0.3 * confidence).clamp(0, 1);
      if (s.nextReviewAt != null) {
        scheduled++;
        if (s.isDue(now)) overdue++;
      }
    }
    if (covered == 0) {
      return ReadinessReport(
        readiness: 0,
        passProbability: (1 / (1 + exp(8 * passRatio))).clamp(0.0, 1.0),
        knowledgeCoverage: 0,
        retentionScore: 0,
        confidenceScore: 0,
        topicReadiness: topicReadiness,
      );
    }
    final coverage = covered / allTopicIds.length;
    final avgTopicReadiness = allTopicIds.isEmpty
        ? 0.0
        : topicReadiness.values.fold(0.0, (a, b) => a + b) / allTopicIds.length;
    final retention = scheduled == 0 ? 1.0 : 1 - overdue / scheduled;
    final confidence = covered == 0 ? 0.0 : confidenceSum / covered;

    final mockBoost = model.mockExamScores.isEmpty
        ? 0.0
        : (model.mockExamScores.last - passRatio) * 0.3;
    final readiness =
        (0.6 * avgTopicReadiness + 0.2 * coverage + 0.2 * retention + mockBoost)
            .clamp(0.0, 1.0);
    final passProbability = (1 / (1 + exp(-8 * (readiness - passRatio)))).clamp(
      0.0,
      1.0,
    );

    return ReadinessReport(
      readiness: readiness,
      passProbability: passProbability,
      knowledgeCoverage: coverage,
      retentionScore: retention,
      confidenceScore: confidence,
      topicReadiness: topicReadiness,
    );
  }

  // ---------------------------------------------------------- study plan

  StudyPlan studyPlan(
    LearnerModel model, {
    required List<String> allTopicIds,
    required DateTime now,
    int maxItems = 5,
  }) {
    final items = <StudyPlanItem>[];
    var due = 0;

    for (final id in allTopicIds) {
      final s = model.concepts[id];
      if (s == null || s.attempts == 0) {
        items.add(
          StudyPlanItem(
            conceptId: id,
            reason: 'not seen yet',
            suggestedQuestions: 6,
          ),
        );
      } else if (s.isDue(now)) {
        due++;
        items.add(
          StudyPlanItem(
            conceptId: id,
            reason: 'due for review',
            suggestedQuestions: 4,
          ),
        );
      } else if (conceptConfidence(s) < 0.5) {
        items.add(
          StudyPlanItem(
            conceptId: id,
            reason: 'weak — needs practice',
            suggestedQuestions: 6,
          ),
        );
      }
    }

    const priority = {
      'due for review': 0,
      'weak — needs practice': 1,
      'not seen yet': 2,
    };
    items.sort((a, b) => priority[a.reason]!.compareTo(priority[b.reason]!));
    final selected = items.take(maxItems).toList();
    final questionCount = selected.fold(
      0,
      (sum, i) => sum + i.suggestedQuestions,
    );
    // ~30s per question incl. reading the explanation.
    final minutes = (questionCount * 0.5).ceil();

    final r = readiness(
      model,
      allTopicIds: allTopicIds,
      passRatio: 0.8,
      now: now,
    );
    return StudyPlan(
      items: selected,
      estimatedMinutes: minutes,
      recommendMockExam:
          r.readiness >= 0.7 &&
          (model.mockExamScores.isEmpty ||
              model.mockExamScores.last < r.readiness),
      dueReviewCount: due,
    );
  }

  // -------------------------------------------------------- learning DNA

  /// Derived long-term traits; recomputed, never stored as truth.
  Set<LearningTrait> learningDna(LearnerModel model) {
    if (model.totalAnswered < 10) return const {};
    final stats = model.concepts.values.where((s) => s.attempts > 0).toList();
    if (stats.isEmpty) return const {};

    final avgSeconds =
        stats.fold(0.0, (a, s) => a + s.avgResponseSeconds) / stats.length;
    final accuracy = model.overallAccuracy;
    final avgConfidence =
        stats.fold(0.0, (a, s) => a + conceptConfidence(s)) / stats.length;
    final totalLapses = stats.fold(0, (a, s) => a + s.lapses);
    final lapseRate = totalLapses / model.totalAnswered;
    final masteryVariance = _variance([for (final s in stats) s.mastery]);

    return {
      if (avgSeconds < 8) LearningTrait.fastResponder,
      if (avgSeconds > 20 && accuracy > 0.8) LearningTrait.slowButAccurate,
      if (avgConfidence < 0.4 && accuracy > 0.6) LearningTrait.lowConfidence,
      if (avgConfidence > 0.7) LearningTrait.highConfidence,
      if (avgSeconds < 6 && accuracy < 0.6)
        LearningTrait.strugglesUnderTimePressure,
      if (lapseRate > 0.15) LearningTrait.repeatsMistakes,
      if (lapseRate <= 0.05 && model.studyDays.length >= 3)
        LearningTrait.benefitsFromRepetition,
      if (masteryVariance < 0.05 && stats.length >= 3) LearningTrait.consistent,
    };
  }

  /// Mastery gained per study day — learning velocity proxy.
  double learningVelocity(LearnerModel model) {
    if (model.studyDays.isEmpty) return 0;
    final totalMastery = model.concepts.values.fold(
      0.0,
      (a, s) => a + s.mastery,
    );
    return totalMastery / model.studyDays.length;
  }
}

double _ewma(double current, double target, double alpha) =>
    current + alpha * (target - current);

double _variance(List<double> values) {
  if (values.isEmpty) return 0;
  final mean = values.fold(0.0, (a, b) => a + b) / values.length;
  return values.fold(0.0, (a, v) => a + (v - mean) * (v - mean)) /
      values.length;
}
