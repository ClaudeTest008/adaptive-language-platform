import 'entities.dart';
import 'learning_profile.dart';
import 'notebook.dart';
import 'teacher_brain.dart';

/// Teaching Style Engine + Adaptive Pedagogy (Phase 20). Pure, deterministic,
/// offline. Given the brain's facts and the learning profile, it decides HOW
/// to teach: the presentation style, the difficulty setting, whether to drop
/// into recovery/review, and how likely a lesson is to succeed. The UI never
/// chooses — this engine does, optimizing long-term learning (retention,
/// confidence, motivation) over lesson completion.

/// How a lesson should be presented.
enum TeachingStyle {
  exampleFirst,
  grammarFirst,
  storyFirst,
  conversationFirst,
  reviewFirst,
  challengeFirst,
  encouragementFirst,
  connectionExplanation,
  questionFirst,
}

/// How corrections should be delivered.
enum CorrectionStyle { minimal, gentle, detailed }

/// Continuous difficulty estimate for current material.
enum DifficultyFit { tooEasy, ideal, tooDifficult, unknown }

/// The engine's full pedagogical decision.
class PedagogyDecision {
  const PedagogyDecision({
    required this.style,
    required this.correctionStyle,
    required this.difficulty,
    required this.recoveryMode,
    required this.rationale,
  });

  final TeachingStyle style;
  final CorrectionStyle correctionStyle;
  final DifficultyFit difficulty;

  /// True when recent sessions show struggle — review instead of new material.
  final bool recoveryMode;
  final String rationale;
}

/// Readiness analytics (Phase 20, architecture): typed scores computed only
/// from real measurements — null when unmeasured, never fabricated.
class ReadinessScores {
  const ReadinessScores({
    this.speakingReadiness,
    this.readingReadiness,
    this.conversationReadiness,
    this.retention,
    this.learningEfficiency,
  });

  final double? speakingReadiness;
  final double? readingReadiness;
  final double? conversationReadiness;

  /// Mastery held across sessions (needs ≥2 snapshots).
  final double? retention;

  /// Accuracy per answered volume (needs enough answers).
  final double? learningEfficiency;
}

/// Teacher reflection after a lesson (Phase 20, typed model). Derived
/// observations only — no producer records these yet (wired when lesson
/// outcomes land in the roleplay phase); the type exists so reflection can
/// grow without a migration.
class TeacherReflection {
  const TeacherReflection({
    required this.day,
    this.whatWorked = const [],
    this.whatConfused = const [],
    this.whatImproved = const [],
    this.nextAdjustment,
  });

  final String day;
  final List<String> whatWorked;
  final List<String> whatConfused;
  final List<String> whatImproved;
  final String? nextAdjustment;
}

double _avg(Iterable<double> xs) {
  final l = xs.toList();
  return l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
}

/// Detects sustained struggle from snapshot history: mastery declining across
/// the last [window] recorded sessions.
bool detectStruggle(List<NotebookSnapshot> history, {int window = 3}) {
  if (history.length < window) return false;
  final recent = history.sublist(history.length - window);
  var declines = 0;
  for (var i = 1; i < recent.length; i++) {
    if (_avg(recent[i].mastery.values) < _avg(recent[i - 1].mastery.values)) {
      declines++;
    }
  }
  return declines >= window - 1;
}

/// Estimates how well current material fits the learner.
DifficultyFit estimateDifficulty({
  required double accuracy,
  required int totalAnswered,
}) {
  if (totalAnswered < 10) return DifficultyFit.unknown;
  if (accuracy >= 0.9) return DifficultyFit.tooEasy;
  if (accuracy < 0.5) return DifficultyFit.tooDifficult;
  return DifficultyFit.ideal;
}

/// Predicts the probability (0…1) that a lesson on [conceptId] succeeds,
/// from prerequisite mastery and overall fit. Below ~0.4 the caller should
/// schedule prerequisites first.
double predictSuccess({
  required String conceptId,
  required Map<String, double> conceptMastery,
  required List<String> prerequisiteIds,
  required double accuracy,
}) {
  final prereqs = [
    for (final id in prerequisiteIds) conceptMastery[id] ?? 0.0,
  ];
  final prereqScore = prereqs.isEmpty ? 0.6 : _avg(prereqs);
  final own = conceptMastery[conceptId] ?? 0.0;
  // Prerequisites dominate; some credit for prior exposure and general form.
  final p = 0.55 * prereqScore + 0.2 * own + 0.25 * accuracy;
  return double.parse(p.clamp(0.0, 1.0).toStringAsFixed(2));
}

/// Computes readiness analytics from real measurements only.
ReadinessScores computeReadiness({
  required LearnerFacts facts,
  required ConfidenceModel confidence,
  required List<NotebookSnapshot> history,
}) {
  double? skill(LanguageSkill s) {
    final v = facts.skills[s]?.level;
    return (v == null || v == 0) ? null : v;
  }

  double? blend(double? level, LanguageSkill s) {
    if (level == null) return null;
    final c = confidence.bySkill[s];
    final v = c == null ? level : (level + c) / 2;
    return double.parse(v.toStringAsFixed(2));
  }

  final vocab = skill(LanguageSkill.vocabulary);
  final listening = skill(LanguageSkill.listening);
  double? retention;
  if (history.length >= 2) {
    final first = _avg(history.first.mastery.values);
    final last = _avg(history.last.mastery.values);
    retention = first == 0
        ? null
        : double.parse((last / first).clamp(0.0, 2.0).toStringAsFixed(2));
  }
  return ReadinessScores(
    speakingReadiness: blend(skill(LanguageSkill.speaking), LanguageSkill.speaking),
    readingReadiness: vocab == null
        ? null
        : double.parse(vocab.toStringAsFixed(2)),
    conversationReadiness: (vocab != null && listening != null)
        ? double.parse(_avg([vocab, listening]).toStringAsFixed(2))
        : null,
    retention: retention,
    learningEfficiency: facts.totalAnswered < 10
        ? null
        : double.parse(facts.accuracy.toStringAsFixed(2)),
  );
}

/// The Teaching Style Engine: chooses how to teach from the brain's facts and
/// the learning profile.
class TeachingStyleEngine {
  const TeachingStyleEngine();

  PedagogyDecision decide({
    required LearnerFacts facts,
    required LearningProfile profile,
    required List<NotebookSnapshot> history,
  }) {
    final struggle = detectStruggle(history);
    final difficulty = estimateDifficulty(
      accuracy: facts.accuracy,
      totalAnswered: facts.totalAnswered,
    );

    // Recovery beats everything: stop introducing new concepts.
    if (struggle || difficulty == DifficultyFit.tooDifficult) {
      return PedagogyDecision(
        style: TeachingStyle.reviewFirst,
        correctionStyle: CorrectionStyle.gentle,
        difficulty: difficulty,
        recoveryMode: true,
        rationale: struggle
            ? 'Recent sessions show sustained struggle — we review and rebuild '
                  'before anything new.'
            : 'Current material is running too hard — we consolidate first.',
      );
    }

    // Strained motivation: encourage before challenging.
    if (profile.motivation.state == MotivationState.strained) {
      return PedagogyDecision(
        style: TeachingStyle.encouragementFirst,
        correctionStyle: CorrectionStyle.minimal,
        difficulty: difficulty,
        recoveryMode: false,
        rationale: 'Momentum dipped — start with wins, keep corrections light.',
      );
    }

    // Profile-driven presentation.
    final style = profile.has(LearningTraitKind.strongReader)
        ? TeachingStyle.storyFirst
        : profile.has(LearningTraitKind.avoidsSpeaking)
        ? TeachingStyle.conversationFirst // ease speaking in via dialogue
        : profile.has(LearningTraitKind.needsRepetition)
        ? TeachingStyle.reviewFirst
        : profile.has(LearningTraitKind.fastLearner) &&
              difficulty == DifficultyFit.tooEasy
        ? TeachingStyle.challengeFirst
        : TeachingStyle.connectionExplanation;

    final correction = profile.has(LearningTraitKind.respondsToEncouragement)
        ? CorrectionStyle.gentle
        : CorrectionStyle.detailed;

    return PedagogyDecision(
      style: style,
      correctionStyle: correction,
      difficulty: difficulty,
      recoveryMode: false,
      rationale: switch (style) {
        TeachingStyle.storyFirst =>
          'You learn well through reading — we open with a story.',
        TeachingStyle.conversationFirst =>
          'We ease speaking in through dialogue, low pressure.',
        TeachingStyle.reviewFirst =>
          'Repetition works for you — we revisit before extending.',
        TeachingStyle.challengeFirst =>
          "Material is running easy and you're fast — time to stretch.",
        _ => 'We teach by connecting new material to what you already know.',
      },
    );
  }
}
