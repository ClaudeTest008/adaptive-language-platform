import 'experience.dart';

/// Reading Analytics Engine (Phase 33). Pure, deterministic, offline. Computes
/// ONLY measured values from the learner's reading records — every field is
/// null when the underlying data was never captured, never estimated. The
/// current reader does not yet instrument timing/replay per session, so those
/// fields are typed nullable seams for future UI instrumentation; today they
/// stay null rather than being invented.

/// One reading session's raw instrumentation. The reader populates what it
/// measures; unmeasured fields stay null (no fabrication).
class ReadingSessionInput {
  const ReadingSessionInput({
    required this.record,
    this.durationMs,
    this.pauseCount,
    this.sentenceReplays,
    this.paragraphReplays,
    this.pagesRevisited,
    this.wordTaps,
    this.completed = true,
  });

  final ReadingRecord record;
  final int? durationMs;
  final int? pauseCount;
  final int? sentenceReplays;
  final int? paragraphReplays;
  final int? pagesRevisited;
  final int? wordTaps;
  final bool completed;

  int get wordsRead =>
      record.knownRatio == 0 && record.unknownWords.isEmpty ? 0 : 1;
}

/// Aggregated, measured reading analytics across the learner's history.
class ReadingAnalyticsReport {
  const ReadingAnalyticsReport({
    required this.booksRead,
    required this.meanComprehension,
    this.wordsPerMinute,
    this.meanDurationMs,
    this.pauseFrequency,
    this.replayCount,
    this.completionRate,
    this.abandonmentCount = 0,
    this.longestStreakDays = 0,
    this.unknownWordDensity,
    this.readingConsistency,
  });

  final int booksRead;

  /// Mean known-word ratio across finished books (a comprehension proxy).
  final double meanComprehension;

  /// Null until the reader measures duration.
  final double? wordsPerMinute;
  final int? meanDurationMs;
  final double? pauseFrequency;
  final int? replayCount;

  /// Finished / started; null when nothing was started.
  final double? completionRate;
  final int abandonmentCount;
  final int longestStreakDays;

  /// Unknown words / books — a measured difficulty signal.
  final double? unknownWordDensity;

  /// Distinct reading days over the span (0…1); null with <2 records.
  final double? readingConsistency;

  bool get isEmpty => booksRead == 0;
}

double _mean(Iterable<double> xs) {
  final l = xs.toList();
  return l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
}

int _daysBetween(String a, String b) {
  try {
    return DateTime.parse(b).difference(DateTime.parse(a)).inDays.abs();
  } catch (_) {
    return 0;
  }
}

/// Longest run of consecutive reading days from the record days.
int _longestStreak(List<String> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toSet().toList()..sort();
  var best = 1, run = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (_daysBetween(sorted[i - 1], sorted[i]) == 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}

/// Builds the report from reading records + optional per-session instrumentation
/// (keyed by story id). Everything measured; null when unmeasured.
ReadingAnalyticsReport computeReadingReport(
  List<ReadingRecord> records, {
  Map<String, ReadingSessionInput> sessions = const {},
}) {
  if (records.isEmpty) {
    return const ReadingAnalyticsReport(booksRead: 0, meanComprehension: 0);
  }
  final comprehension = _mean(records.map((r) => r.knownRatio));
  final unknownTotal = records.fold(0, (n, r) => n + r.unknownWords.length);
  final days = [for (final r in records) r.day];
  final distinctDays = days.toSet().length;
  final span = days.isEmpty
      ? 0
      : _daysBetween(
          (days.toList()..sort()).first, (days.toList()..sort()).last);

  // Timing/replay only when the reader actually instrumented sessions.
  final durations = [
    for (final s in sessions.values)
      if (s.durationMs != null) s.durationMs!,
  ];
  final replays = [
    for (final s in sessions.values)
      (s.sentenceReplays ?? 0) + (s.paragraphReplays ?? 0),
  ];
  final abandoned = sessions.values.where((s) => !s.completed).length;

  return ReadingAnalyticsReport(
    booksRead: records.length,
    meanComprehension: double.parse(comprehension.toStringAsFixed(2)),
    wordsPerMinute: null, // reader does not measure words/time yet (seam)
    meanDurationMs: durations.isEmpty
        ? null
        : (durations.reduce((a, b) => a + b) / durations.length).round(),
    pauseFrequency: null,
    replayCount: replays.isEmpty ? null : replays.reduce((a, b) => a + b),
    completionRate: sessions.isEmpty
        ? null
        : double.parse(
            ((sessions.length - abandoned) / sessions.length)
                .toStringAsFixed(2)),
    abandonmentCount: abandoned,
    longestStreakDays: _longestStreak(days),
    unknownWordDensity:
        double.parse((unknownTotal / records.length).toStringAsFixed(2)),
    readingConsistency: records.length < 2 || span == 0
        ? null
        : double.parse((distinctDays / (span + 1)).clamp(0.0, 1.0)
            .toStringAsFixed(2)),
  );
}
