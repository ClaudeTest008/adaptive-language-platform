/// Adaptive question selection (ADR-0008): replaces random selection with
/// priority buckets — due reviews, weak concepts, unseen material, then
/// consolidation — with difficulty matched to current mastery.
library;

import 'dart:math';

import '../domain/models.dart';
import 'engine.dart';
import 'graph.dart';
import 'model.dart';

abstract class QuestionSelector {
  List<Question> select({
    required List<Question> pool,
    required LearnerModel model,
    required int count,
    required DateTime now,
  });
}

class AdaptiveQuestionSelector implements QuestionSelector {
  AdaptiveQuestionSelector({required this.engine, Random? random})
    : random = random ?? Random();

  final LearnerEngine engine;
  final Random random;

  @override
  List<Question> select({
    required List<Question> pool,
    required LearnerModel model,
    required int count,
    required DateTime now,
  }) {
    final scored = [for (final q in pool) (q, _score(q, model, now))]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (q, _) in scored.take(count)) q];
  }

  /// Higher = pick sooner. Bucket base + in-bucket refinements + jitter
  /// (jitter breaks ties so sessions vary without losing priorities).
  double _score(Question q, LearnerModel model, DateTime now) {
    final primary = model.concepts[q.topicId];
    final jitter = random.nextDouble() * 0.05;

    // Bucket 1: due for review — most overdue first.
    if (primary != null && primary.isDue(now)) {
      final overdueDays =
          now.difference(primary.nextReviewAt!).inMinutes / (60 * 24);
      return 3.0 + min(overdueDays, 10) / 10 + jitter;
    }
    // Bucket 2: weak — least confident first, difficulty matched to
    // mastery (struggling learners get easier questions first).
    if (primary != null && primary.attempts > 0) {
      final confidence = engine.conceptConfidence(primary);
      if (confidence < 0.5) {
        final difficultyFit = 1 - (_difficulty01(q) - primary.mastery).abs();
        return 2.0 + (0.5 - confidence) + 0.3 * difficultyFit + jitter;
      }
      // Bucket 4: consolidation — longest-unseen first.
      final daysSince = primary.lastAnsweredAt == null
          ? 0.0
          : now.difference(primary.lastAnsweredAt!).inMinutes / (60 * 24);
      return 0.0 + min(daysSince, 30) / 30 + jitter;
    }
    // Bucket 3: unseen material.
    return 1.0 + (1 - _difficulty01(q)) * 0.3 + jitter;
  }
}

double _difficulty01(Question q) => switch (q.difficulty) {
  Difficulty.easy => 0.0,
  Difficulty.medium => 0.5,
  Difficulty.hard => 1.0,
};

/// Builds an [AnswerEvent] from an answered question — the single
/// translation point between domain and engine.
AnswerEvent answerEventFor(
  Question q, {
  required bool correct,
  required double responseSeconds,
  required DateTime answeredAt,
}) => AnswerEvent(
  questionId: q.id,
  conceptIds: conceptsForQuestion(q),
  correct: correct,
  responseSeconds: responseSeconds,
  difficulty01: _difficulty01(q),
  answeredAt: answeredAt,
);
