import 'experience.dart';
import 'reading_analytics.dart';
import 'recommendation_engine.dart';
import 'vocabulary_growth.dart';

/// Reader Intelligence Engine (Phase 33). Pure, deterministic, offline. Turns
/// the reader from a story viewer into a measured learning producer: it
/// consumes the reading records, the measured reading analytics and the
/// vocabulary growth, and derives a [ReaderProfile] — confidence, difficulty
/// fit, momentum, habits, strengths/weaknesses, insights, a prediction, and
/// reading recommendations that MERGE into the single Recommendation Engine
/// output (not a second recommendation system). Everything measured; empty
/// history yields an empty profile; unmeasured values stay null.

enum ReadingDifficultyFit { tooEasy, ideal, tooHard, unknown }

class ReadingPrediction {
  const ReadingPrediction({
    this.readyForHarder,
    this.nextReviewWords = const [],
  });

  /// True/false when comprehension + difficulty support a call; null otherwise.
  final bool? readyForHarder;
  final List<String> nextReviewWords;
}

class ReaderProfile {
  const ReaderProfile({
    required this.booksRead,
    this.readingConfidence,
    this.difficultyFit = ReadingDifficultyFit.unknown,
    this.momentum = 0,
    this.habits = const [],
    this.strengths = const [],
    this.weaknesses = const [],
    this.insights = const [],
    this.prediction = const ReadingPrediction(),
    this.recommendations = const [],
  });

  final int booksRead;

  /// 0…1 measured comprehension proxy; null with no finished books.
  final double? readingConfidence;
  final ReadingDifficultyFit difficultyFit;

  /// Reading momentum (-1…1) from vocabulary growth.
  final double momentum;
  final List<String> habits;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> insights;
  final ReadingPrediction prediction;

  /// Reading recommendations, ready to merge into the Recommendation Engine.
  final List<Recommendation> recommendations;

  bool get isEmpty => booksRead == 0;
}

/// Builds the reader profile from measured evidence.
ReaderProfile buildReaderProfile({
  required List<ReadingRecord> records,
  required ReadingAnalyticsReport analytics,
  required VocabularyGrowth vocabulary,
}) {
  if (records.isEmpty) {
    return const ReaderProfile(booksRead: 0);
  }

  final comprehension = analytics.meanComprehension;
  final density = analytics.unknownWordDensity ?? 0;
  final fit = comprehension >= 0.85 && density < 2
      ? ReadingDifficultyFit.tooEasy
      : comprehension < 0.4 || density > 8
      ? ReadingDifficultyFit.tooHard
      : ReadingDifficultyFit.ideal;

  final habits = <String>[
    if (analytics.longestStreakDays >= 3) 'reads on a streak',
    if ((analytics.readingConsistency ?? 0) >= 0.5) 'reads consistently',
    if (analytics.abandonmentCount >= 2) 'tends to abandon harder books',
  ];
  final strengths = <String>[
    if (comprehension >= 0.7) 'strong comprehension',
    if (vocabulary.stableVocabulary.length >= 5) 'growing stable vocabulary',
  ];
  final weaknesses = <String>[
    if (fit == ReadingDifficultyFit.tooHard) 'material is running hard',
    if (vocabulary.frequentlyForgotten.isNotEmpty)
      'some words keep slipping',
  ];
  final insights = <String>[
    'Read ${records.length} '
        '${records.length == 1 ? 'book' : 'books'}, '
        'comprehension ${(comprehension * 100).round()}%.',
    if (vocabulary.momentum > 0) 'Vocabulary is growing.',
    if (vocabulary.momentum < 0) 'Vocabulary growth has slowed.',
  ];

  final recs = <Recommendation>[
    if (fit == ReadingDifficultyFit.tooHard)
      const Recommendation(
        id: 'read-easier',
        kind: RecommendationKind.reading,
        priority: 2,
        reason: 'These books are running hard — an easier story rebuilds flow.',
        urgency: 0.5,
        expectedValue: 0.6,
        confidence: 0.7,
      ),
    if (fit == ReadingDifficultyFit.tooEasy)
      const Recommendation(
        id: 'read-harder',
        kind: RecommendationKind.story,
        priority: 4,
        reason: 'Reading is comfortable — a harder story will stretch you.',
        urgency: 0.3,
        expectedValue: 0.6,
        confidence: 0.7,
      ),
    if (vocabulary.reviewCandidates.isNotEmpty)
      Recommendation(
        id: 'vocab-review',
        kind: RecommendationKind.review,
        priority: 2,
        reason:
            'Review words that keep slipping: '
            '${vocabulary.reviewCandidates.take(3).join(', ')}.',
        requiredConcepts: vocabulary.reviewCandidates.take(5).toList(),
        urgency: 0.55,
        expectedValue: 0.65,
        confidence: 0.8,
      ),
  ];

  return ReaderProfile(
    booksRead: records.length,
    readingConfidence: double.parse(comprehension.toStringAsFixed(2)),
    difficultyFit: fit,
    momentum: vocabulary.momentum,
    habits: habits,
    strengths: strengths,
    weaknesses: weaknesses,
    insights: insights,
    prediction: ReadingPrediction(
      readyForHarder: comprehension >= 0.8
          ? true
          : comprehension < 0.5
          ? false
          : null,
      nextReviewWords: vocabulary.reviewCandidates.take(5).toList(),
    ),
    recommendations: recs,
  );
}
