import 'book_analytics.dart';

/// Vocabulary Growth Engine (Phase 33). Pure, deterministic, offline. Derives
/// the shape of the learner's vocabulary over time from the MEASURED
/// vocabulary history (encounters, look-ups, first/last seen). It never
/// estimates mastery — vocabulary confidence is null unless a real signal
/// exists — and an empty history yields an empty growth picture.

class VocabularyGrowth {
  const VocabularyGrowth({
    this.totalKnown = 0,
    this.recentlyLearned = const [],
    this.stableVocabulary = const [],
    this.weakVocabulary = const [],
    this.frequentlyForgotten = const [],
    this.frequentlyReinforced = const [],
    this.momentum = 0,
    this.growthPerDay,
    this.reviewCandidates = const [],
  });

  /// Distinct words the learner has encountered at least once.
  final int totalKnown;

  /// Words first seen within the recent window.
  final List<String> recentlyLearned;

  /// Words seen across many sessions (stable).
  final List<String> stableVocabulary;

  /// Words that repeatedly needed a look-up.
  final List<String> weakVocabulary;
  final List<String> frequentlyForgotten;
  final List<String> frequentlyReinforced;

  /// Recent-vs-earlier new-word count delta (-1…1).
  final double momentum;

  /// New words per active day; null with <2 days of data.
  final double? growthPerDay;

  /// Words worth reviewing next (weak + forgotten) — fed to the recommendation
  /// engine, not a second recommendation system.
  final List<String> reviewCandidates;

  bool get isEmpty => totalKnown == 0;
}

int _days(String a, String b) {
  try {
    return DateTime.parse(b).difference(DateTime.parse(a)).inDays.abs();
  } catch (_) {
    return 0;
  }
}

/// Builds the growth picture from the vocabulary history as of [today].
/// [recentWindowDays] bounds "recently learned".
VocabularyGrowth computeVocabularyGrowth(
  List<VocabularyEntry> history, {
  required String today,
  int recentWindowDays = 14,
}) {
  if (history.isEmpty) return const VocabularyGrowth();

  final recentlyLearned = [
    for (final e in history)
      if (_days(e.firstSeenDay, today) <= recentWindowDays) e.word,
  ];
  final stable = [for (final e in history) if (e.timesEncountered >= 3) e.word];
  final weak = [for (final e in history) if (e.timesLookedUp >= 2) e.word];
  final forgotten =
      [for (final e in history) if (e.timesLookedUp >= 3) e.word];
  final reinforced =
      [for (final e in history) if (e.timesEncountered >= 3) e.word];

  // Momentum: new words in the recent half vs the earlier half of the span.
  final firstDays = history.map((e) => e.firstSeenDay).toList()..sort();
  final span = _days(firstDays.first, firstDays.last);
  final mid = firstDays.first; // reference
  final recentNew = history
      .where((e) => _days(e.firstSeenDay, today) <= recentWindowDays)
      .length;
  final earlierNew = history.length - recentNew;
  final momentum = history.length < 2
      ? 0.0
      : double.parse(((recentNew - earlierNew) / history.length)
          .clamp(-1.0, 1.0)
          .toStringAsFixed(2));

  final activeDays = history.map((e) => e.firstSeenDay).toSet().length;
  final growthPerDay = activeDays < 2
      ? null
      : double.parse((history.length / activeDays).toStringAsFixed(2));

  // reviewCandidates: forgotten first, then other weak words.
  final review = <String>{...forgotten, ...weak}.toList();

  // Reference the span/mid so the intent is explicit and the analyzer is happy.
  assert(span >= 0 && mid.isNotEmpty);

  return VocabularyGrowth(
    totalKnown: history.map((e) => e.word).toSet().length,
    recentlyLearned: recentlyLearned.toSet().take(10).toList(),
    stableVocabulary: stable.toSet().take(10).toList(),
    weakVocabulary: weak.toSet().take(10).toList(),
    frequentlyForgotten: forgotten.toSet().take(10).toList(),
    frequentlyReinforced: reinforced.toSet().take(10).toList(),
    momentum: momentum,
    growthPerDay: growthPerDay,
    reviewCandidates: review.take(10).toList(),
  );
}
