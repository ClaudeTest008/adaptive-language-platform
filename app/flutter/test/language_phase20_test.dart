import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/learning_profile.dart';
import 'package:adaptive_exam_platform/language/notebook.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/teaching_planner.dart';
import 'package:adaptive_exam_platform/language/teaching_style.dart';
import 'package:adaptive_exam_platform/language/tutor.dart';
import 'package:flutter_test/flutter_test.dart';

LearnerFacts _facts({
  Map<LanguageSkill, double> skills = const {
    LanguageSkill.vocabulary: 0.6,
    LanguageSkill.grammar: 0.5,
    LanguageSkill.listening: 0.7,
    LanguageSkill.reading: 0.4,
    LanguageSkill.speaking: 0.2,
  },
  double accuracy = 0.65,
  int totalAnswered = 40,
}) => LearnerFacts(
  skills: {
    for (final e in skills.entries)
      e.key: SkillState(
        skill: e.key,
        level: e.value,
        confidence: e.value,
        trend: Trend.unknown,
      ),
  },
  grammar: const [],
  vocabulary: const VocabularySummary(mastery: 0.6, estimatedKnown: 60),
  pronunciation: const PronunciationState(),
  accuracy: accuracy,
  totalAnswered: totalAnswered,
  cefr: 'A1',
);

NotebookSnapshot _snap(String day, double mastery) => NotebookSnapshot(
  day: day,
  mastery: {LanguageSkill.grammar: mastery},
  accuracy: 0.5,
  misconceptionTotal: 0,
);

void main() {
  group('deriveLearningProfile', () {
    test('DNA traits become typed, explainable profile traits', () {
      final p = deriveLearningProfile(
        facts: _facts(),
        learningDna: const ['benefitsFromRepetition', 'slowButAccurate'],
        history: const [],
      );
      expect(p.has(LearningTraitKind.needsRepetition), isTrue);
      expect(p.has(LearningTraitKind.slowButDurable), isTrue);
      expect(p.traits.first.evidence, isNotEmpty);
    });

    test('detects speaking avoidance from skill balance', () {
      final p = deriveLearningProfile(
        facts: _facts(),
        learningDna: const [],
        history: const [],
      );
      expect(p.has(LearningTraitKind.avoidsSpeaking), isTrue);
      // Confidence separate from mastery: speaking confidence dragged down.
      final speakConf = p.confidence.bySkill[LanguageSkill.speaking]!;
      expect(speakConf, lessThan(0.2 + 0.01)); // below its own mastery blend
    });

    test('strong listener detected when ears lead eyes', () {
      final p = deriveLearningProfile(
        facts: _facts(),
        learningDna: const [],
        history: const [],
      );
      expect(p.has(LearningTraitKind.strongListener), isTrue);
    });

    test('motivation unknown without history, flowing when mastery rises', () {
      final none = deriveLearningProfile(
        facts: _facts(),
        learningDna: const [],
        history: const [],
      );
      expect(none.motivation.state, MotivationState.unknown);

      final rising = deriveLearningProfile(
        facts: _facts(),
        learningDna: const [],
        history: [_snap('2026-07-16', 0.3), _snap('2026-07-17', 0.5)],
        streakDays: 3,
      );
      expect(rising.motivation.state, MotivationState.flowing);
      expect(rising.motivation.momentum, greaterThan(0));
    });

    test('no fabrication: speed/tolerance null under 10 answers', () {
      final p = deriveLearningProfile(
        facts: _facts(totalAnswered: 3),
        learningDna: const [],
        history: const [],
      );
      expect(p.learningSpeed, isNull);
      expect(p.difficultyTolerance, isNull);
    });
  });

  group('TeachingStyleEngine', () {
    test('recovery mode on sustained decline — review, no new concepts', () {
      final d = const TeachingStyleEngine().decide(
        facts: _facts(),
        profile: const LearningProfile(),
        history: [
          _snap('2026-07-15', 0.6),
          _snap('2026-07-16', 0.5),
          _snap('2026-07-17', 0.4),
        ],
      );
      expect(d.recoveryMode, isTrue);
      expect(d.style, TeachingStyle.reviewFirst);
    });

    test('too-difficult material triggers consolidation', () {
      final d = const TeachingStyleEngine().decide(
        facts: _facts(accuracy: 0.3),
        profile: const LearningProfile(),
        history: const [],
      );
      expect(d.recoveryMode, isTrue);
      expect(d.difficulty, DifficultyFit.tooDifficult);
    });

    test('profile drives presentation: avoids-speaking → conversation-first',
        () {
      final profile = deriveLearningProfile(
        facts: _facts(),
        learningDna: const [],
        history: const [],
      );
      final d = const TeachingStyleEngine().decide(
        facts: _facts(),
        profile: profile,
        history: const [],
      );
      expect(d.recoveryMode, isFalse);
      expect(d.style, TeachingStyle.conversationFirst);
    });

    test('difficulty fit: unknown under 10 answers, easy at 90%+', () {
      expect(
        estimateDifficulty(accuracy: 0.95, totalAnswered: 5),
        DifficultyFit.unknown,
      );
      expect(
        estimateDifficulty(accuracy: 0.95, totalAnswered: 30),
        DifficultyFit.tooEasy,
      );
    });
  });

  group('predictSuccess', () {
    test('low without prerequisites, high with them mastered', () {
      final low = predictSuccess(
        conceptId: 'es:a1:grammar:subjunctive',
        conceptMastery: const {},
        prerequisiteIds: const ['es:a1:grammar:present'],
        accuracy: 0.5,
      );
      final high = predictSuccess(
        conceptId: 'es:a1:grammar:subjunctive',
        conceptMastery: const {'es:a1:grammar:present': 0.9},
        prerequisiteIds: const ['es:a1:grammar:present'],
        accuracy: 0.8,
      );
      expect(low, lessThan(0.4));
      expect(high, greaterThan(0.6));
    });
  });

  group('computeReadiness', () {
    test('scores only from real measurements — null when unmeasured', () {
      final r = computeReadiness(
        facts: _facts(),
        confidence: const ConfidenceModel(),
        history: const [],
      );
      expect(r.readingReadiness, isNotNull);
      expect(r.conversationReadiness, isNotNull);
      expect(r.retention, isNull); // needs ≥2 snapshots
    });

    test('retention from snapshot history', () {
      final r = computeReadiness(
        facts: _facts(),
        confidence: const ConfidenceModel(),
        history: [_snap('2026-07-16', 0.4), _snap('2026-07-17', 0.5)],
      );
      expect(r.retention, isNotNull);
      expect(r.retention, greaterThan(1.0)); // mastery grew
    });
  });

  group('brain integration', () {
    TeacherBrain brain({List<NotebookSnapshot> history = const []}) =>
        const OfflineReasoningEngine().assemble(
          BrainInputs(
            today: DateTime(2026, 7, 18),
            nativeLanguage: 'en',
            targetLanguage: 'es',
            targetLanguageName: 'Spanish',
            baseLevel: 'A1',
            longTermGoal: 'Reach A2 Spanish',
            skillMastery: const {
              LanguageSkill.vocabulary: 0.6,
              LanguageSkill.grammar: 0.5,
              LanguageSkill.speaking: 0.2,
              LanguageSkill.listening: 0.7,
            },
            conceptMastery: const {},
            conceptNames: const {},
            misconceptions: const [],
            accuracy: 0.65,
            totalAnswered: 40,
            learningDna: const ['benefitsFromRepetition'],
            historyDays: const [],
            vocabularyPoolSize: 100,
            history: history,
          ),
        );

    test('brain carries profile, pedagogy and readiness', () {
      final b = brain();
      expect(b.profile.traits, isNotEmpty);
      expect(b.pedagogy, isNotNull);
      expect(b.readiness.readingReadiness, isNotNull);
    });

    test('recovery propagates into the unified teaching choice', () {
      final b = brain(
        history: [
          _snap('2026-07-15', 0.6),
          _snap('2026-07-16', 0.5),
          _snap('2026-07-17', 0.4),
        ],
      );
      expect(b.pedagogy!.recoveryMode, isTrue);
      final choice = chooseTeachingStrategy(b);
      expect(choice.mode, TutorMode.teacher);
      expect(choice.rationale, contains('review'));
    });
  });
}
