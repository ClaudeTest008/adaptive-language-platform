/// Business rules that span entities: mock exam composition, scoring,
/// weak-topic detection. Pure Dart, unit-tested.
library;

import 'dart:math';

import '../domain/models.dart';

/// Random sample of [count] questions from [pool] (whole pool if smaller).
List<Question> buildMockExam(List<Question> pool, int count, Random random) {
  final shuffled = List<Question>.of(pool)..shuffle(random);
  return shuffled.take(count).toList();
}

class MockResult {
  const MockResult({
    required this.score,
    required this.total,
    required this.passed,
  });

  final int score;
  final int total;
  final bool passed;
}

/// Scores selections (questionId -> selected answer index); unanswered
/// questions count as wrong.
MockResult scoreMockExam(
  List<Question> questions,
  Map<String, int> selections,
  int passThreshold,
) {
  var score = 0;
  for (final q in questions) {
    final selected = selections[q.id];
    if (selected != null && q.isCorrect(selected)) score++;
  }
  return MockResult(
    score: score,
    total: questions.length,
    passed: score >= passThreshold,
  );
}

/// Topics with enough data and accuracy under [threshold], weakest first.
List<TopicStats> weakTopics(
  Iterable<TopicStats> stats, {
  double threshold = 0.7,
  int minAnswered = 4,
}) {
  final weak =
      stats
          .where((s) => s.answered >= minAnswered && s.accuracy < threshold)
          .toList()
        ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
  return weak;
}
