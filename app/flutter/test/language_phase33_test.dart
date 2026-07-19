import 'package:adaptive_language_platform/language/book_analytics.dart';
import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/experience.dart';
import 'package:adaptive_language_platform/language/lesson_generator.dart';
import 'package:adaptive_language_platform/language/reader_intelligence.dart';
import 'package:adaptive_language_platform/language/reading_analytics.dart';
import 'package:adaptive_language_platform/language/reasoning_engine.dart';
import 'package:adaptive_language_platform/language/recommendation_engine.dart';
import 'package:adaptive_language_platform/language/teacher_brain.dart';
import 'package:adaptive_language_platform/language/teaching_planner.dart';
import 'package:adaptive_language_platform/language/tutor.dart';
import 'package:adaptive_language_platform/language/vocabulary_growth.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingRecord _rec(String day, double known, {List<String> unknown = const []}) =>
    ReadingRecord(day: day, storyId: 's-$day', title: 'Book $day',
        topics: const ['travel'], knownRatio: known, unknownWords: unknown);

VocabularyEntry _v(String w, {int enc = 1, int look = 0, String first = '2026-07-18'}) =>
    VocabularyEntry(word: w, firstSeenDay: first, lastSeenDay: '2026-07-18',
        timesEncountered: enc, timesLookedUp: look);

TeacherBrain _brain() => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: DateTime(2026, 7, 18),
    nativeLanguage: 'en', targetLanguage: 'es', targetLanguageName: 'Spanish',
    baseLevel: 'A1', longTermGoal: 'g',
    skillMastery: const {LanguageSkill.grammar: 0.6}, conceptMastery: const {},
    conceptNames: const {}, misconceptions: const [], accuracy: 0.6,
    totalAnswered: 30, learningDna: const [], historyDays: const [],
    vocabularyPoolSize: 100,
  ),
);

void main() {
  group('reading analytics — measured only, null when unmeasured', () {
    test('comprehension + streak computed; timing null without instrumentation', () {
      final report = computeReadingReport([
        _rec('2026-07-16', 0.8, unknown: ['faro']),
        _rec('2026-07-17', 0.6, unknown: ['bosque', 'mar']),
      ]);
      expect(report.booksRead, 2);
      expect(report.meanComprehension, 0.7);
      expect(report.longestStreakDays, 2);
      expect(report.unknownWordDensity, 1.5);
      expect(report.wordsPerMinute, isNull); // not instrumented (seam)
      expect(report.meanDurationMs, isNull);
    });

    test('empty history → empty report', () {
      expect(computeReadingReport(const []).isEmpty, isTrue);
    });

    test('instrumented sessions populate replay + completion', () {
      final rec = _rec('2026-07-18', 0.7);
      final report = computeReadingReport([rec], sessions: {
        rec.storyId: ReadingSessionInput(
          record: rec, sentenceReplays: 3, completed: true),
      });
      expect(report.replayCount, 3);
      expect(report.completionRate, 1.0);
    });
  });

  group('vocabulary growth — measured', () {
    test('classifies stable, weak, forgotten; empty stays empty', () {
      final growth = computeVocabularyGrowth([
        _v('mar', enc: 4), // stable + reinforced
        _v('faro', look: 3), // forgotten
        _v('bosque', look: 2), // weak
      ], today: '2026-07-18');
      expect(growth.totalKnown, 3);
      expect(growth.stableVocabulary, contains('mar'));
      expect(growth.frequentlyForgotten, contains('faro'));
      expect(growth.reviewCandidates, containsAll(['faro', 'bosque']));

      expect(computeVocabularyGrowth(const [], today: '2026-07-18').isEmpty, isTrue);
    });
  });

  group('reader intelligence', () {
    ReaderProfile profile(List<ReadingRecord> recs, VocabularyGrowth v) =>
        buildReaderProfile(
          records: recs,
          analytics: computeReadingReport(recs),
          vocabulary: v);

    test('derives confidence + difficulty fit + reading recommendations', () {
      final p = profile([
        _rec('2026-07-17', 0.3, unknown: List.filled(10, 'x')),
      ], const VocabularyGrowth(reviewCandidates: ['faro']));
      expect(p.readingConfidence, 0.3);
      expect(p.difficultyFit, ReadingDifficultyFit.tooHard);
      expect(p.prediction.readyForHarder, isFalse);
      expect(p.recommendations.any((r) => r.id == 'read-easier'), isTrue);
      expect(p.recommendations.any((r) => r.id == 'vocab-review'), isTrue);
    });

    test('empty reader → empty profile, nothing fabricated', () {
      final p = profile(const [], const VocabularyGrowth());
      expect(p.isEmpty, isTrue);
      expect(p.readingConfidence, isNull);
      expect(p.difficultyFit, ReadingDifficultyFit.unknown);
    });

    test('deterministic — same input, same profile', () {
      final recs = [_rec('2026-07-18', 0.9)];
      final a = profile(recs, const VocabularyGrowth());
      final b = profile(recs, const VocabularyGrowth());
      expect(a.difficultyFit, b.difficultyFit);
      expect(a.recommendations.map((r) => r.id), b.recommendations.map((r) => r.id));
    });
  });

  group('P32 seam closed — recommendations drive decisions', () {
    test('teaching planner uses a recommendation in the default branch', () {
      final choice = chooseTeachingStrategy(_brain(), recommendations: const [
        Recommendation(id: 'r', kind: RecommendationKind.conversation,
            priority: 3, reason: 'talk more'),
      ]);
      // Empty brain has no misconception/weak-speaker → default branch takes
      // the recommendation (conversation).
      expect(choice.mode, TutorMode.conversation);
      expect(choice.rationale, 'talk more');
    });

    test('lesson generator inserts the top recommendation as a block', () {
      final plan = const AdaptiveLessonGenerator().generate(_brain(),
          recommendations: const [
            Recommendation(id: 'r', kind: RecommendationKind.reading,
                priority: 2, reason: 'read something easier'),
          ]);
      expect(
        plan.recommendations.any((r) => r.rationale == 'read something easier'),
        isTrue,
      );
    });

    test('no recommendations → unchanged default behavior (regression)', () {
      final choice = chooseTeachingStrategy(_brain());
      expect(choice.mode, TutorMode.teacher);
    });
  });
}
