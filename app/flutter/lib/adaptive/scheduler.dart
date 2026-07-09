/// Spaced-repetition scheduling (ADR-0008). The interface is the seam:
/// SM-2, FSRS, or an ML scheduler replace [ExpandingIntervalScheduler]
/// without touching application code.
library;

import 'model.dart';

class ReviewSchedule {
  const ReviewSchedule({
    required this.intervalDays,
    required this.nextReviewAt,
  });

  final double intervalDays;
  final DateTime nextReviewAt;
}

abstract class ReviewScheduler {
  ReviewSchedule schedule({
    required ConceptStats stats,
    required bool correct,
    required DateTime now,
  });
}

/// Expanding-interval baseline: correct answers roughly double the
/// interval (capped), incorrect answers reset to a short interval.
/// ponytail: intentionally simple; upgrade path is SM-2/FSRS behind the
/// same interface.
class ExpandingIntervalScheduler implements ReviewScheduler {
  const ExpandingIntervalScheduler({
    this.firstIntervalDays = 1,
    this.growthFactor = 2.2,
    this.maxIntervalDays = 60,
    this.lapseIntervalDays = 0.5,
  });

  final double firstIntervalDays;
  final double growthFactor;
  final double maxIntervalDays;
  final double lapseIntervalDays;

  @override
  ReviewSchedule schedule({
    required ConceptStats stats,
    required bool correct,
    required DateTime now,
  }) {
    final double interval;
    if (!correct) {
      interval = lapseIntervalDays;
    } else if (stats.intervalDays <= 0) {
      interval = firstIntervalDays;
    } else {
      final grown = stats.intervalDays * growthFactor;
      interval = grown > maxIntervalDays ? maxIntervalDays : grown;
    }
    return ReviewSchedule(
      intervalDays: interval,
      nextReviewAt: now.add(Duration(minutes: (interval * 24 * 60).round())),
    );
  }
}
