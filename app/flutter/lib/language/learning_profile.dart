import 'entities.dart';
import 'notebook.dart';
import 'teacher_brain.dart';

/// Learning Profile (Phase 20) — HOW the learner learns, as opposed to WHAT
/// they know (facts) or what the teacher noticed (notebook). Derived
/// deterministically from real measurements: core Learning DNA traits, skill
/// balances, signals, and snapshot history. Never stored as truth, never
/// fabricated — a trait appears only when the data supports it, and the
/// profile evolves automatically because it is recomputed from live state.

/// A stable, typed vocabulary of learning-style traits.
enum LearningTraitKind {
  needsRepetition,
  fastLearner,
  slowButDurable,
  strongListener,
  strongReader,
  prefersStories,
  avoidsSpeaking,
  respondsToEncouragement,
  strugglesUnderPressure,
  consistentLearner,
  highCuriosity,
}

/// One profile trait with the evidence that justifies it (explainable, like
/// notebook observations).
class LearningProfileTrait {
  const LearningProfileTrait({
    required this.kind,
    required this.description,
    this.evidence = const [],
  });

  final LearningTraitKind kind;
  final String description;
  final List<Evidence> evidence;
}

/// How confident the learner is per skill — deliberately separate from
/// mastery: someone may understand grammar but avoid speaking. Confidence is
/// estimated from behavioural signals (avoidance, DNA confidence traits),
/// mastery from correctness.
class ConfidenceModel {
  const ConfidenceModel({this.bySkill = const {}, this.overall = 0.5});

  final Map<LanguageSkill, double> bySkill;
  final double overall;
}

/// Coarse motivation estimate from real behaviour (streak, trend, struggle).
enum MotivationState { flowing, steady, strained, unknown }

class MotivationModel {
  const MotivationModel({
    this.state = MotivationState.unknown,
    this.momentum = 0,
    this.rationale = '',
  });

  final MotivationState state;

  /// -1…1: recent trend direction scaled by consistency.
  final double momentum;
  final String rationale;
}

/// The assembled profile.
class LearningProfile {
  const LearningProfile({
    this.traits = const [],
    this.confidence = const ConfidenceModel(),
    this.motivation = const MotivationModel(),
    this.learningSpeed,
    this.difficultyTolerance,
  });

  final List<LearningProfileTrait> traits;
  final ConfidenceModel confidence;
  final MotivationModel motivation;

  /// 0…1 relative pace estimate; null until enough answers exist.
  final double? learningSpeed;

  /// 0…1 how much challenge the learner absorbs well; null until measured.
  final double? difficultyTolerance;

  bool has(LearningTraitKind kind) => traits.any((t) => t.kind == kind);
}

double _avg(Iterable<double> xs) {
  final l = xs.toList();
  return l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
}

/// Derives the learning profile from the brain's facts, Learning DNA and
/// snapshot history. Pure; recomputed every brain build so it always evolves.
LearningProfile deriveLearningProfile({
  required LearnerFacts facts,
  required List<String> learningDna,
  required List<NotebookSnapshot> history,
  int streakDays = 0,
}) {
  final dna = learningDna.toSet();
  final traits = <LearningProfileTrait>[];

  void add(LearningTraitKind kind, String description, List<Evidence> ev) =>
      traits.add(
        LearningProfileTrait(kind: kind, description: description, evidence: ev),
      );

  // From core Learning DNA (real engine-derived traits).
  if (dna.contains('benefitsFromRepetition') || dna.contains('repeatsMistakes')) {
    add(
      LearningTraitKind.needsRepetition,
      'Learns best with spaced repetition — mistakes recur until revisited.',
      const [Evidence('Learning DNA', 'repetition helps')],
    );
  }
  if (dna.contains('fastResponder')) {
    add(
      LearningTraitKind.fastLearner,
      'Answers quickly and accurately — can absorb new material fast.',
      const [Evidence('Learning DNA', 'fast responder')],
    );
  }
  if (dna.contains('slowButAccurate')) {
    add(
      LearningTraitKind.slowButDurable,
      'Takes time but retains well — depth over speed.',
      const [Evidence('Learning DNA', 'slow but accurate')],
    );
  }
  if (dna.contains('strugglesUnderTimePressure')) {
    add(
      LearningTraitKind.strugglesUnderPressure,
      'Performs worse under time pressure — avoid timed drills.',
      const [Evidence('Learning DNA', 'time pressure hurts')],
    );
  }
  if (dna.contains('consistent')) {
    add(
      LearningTraitKind.consistentLearner,
      'Shows up regularly — consistency is a strength to build on.',
      const [Evidence('Learning DNA', 'consistent')],
    );
  }
  if (dna.contains('lowConfidence')) {
    add(
      LearningTraitKind.respondsToEncouragement,
      'Confidence trails ability — encouragement and early wins matter.',
      const [Evidence('Learning DNA', 'low confidence')],
    );
  }

  // From skill balances (only when both sides are measured).
  double? lvl(LanguageSkill s) {
    final v = facts.skills[s]?.level;
    return (v == null || v == 0) ? null : v;
  }

  final listening = lvl(LanguageSkill.listening);
  final reading = lvl(LanguageSkill.reading);
  final speaking = lvl(LanguageSkill.speaking);
  final others = [
    for (final e in facts.skills.entries)
      if (e.value.level > 0 && e.key != LanguageSkill.speaking) e.value.level,
  ];
  if (listening != null && reading != null && listening - reading > 0.15) {
    add(
      LearningTraitKind.strongListener,
      'Ears lead the eyes — audio-first material works well.',
      [
        Evidence('Listening', '${(listening * 100).round()}%'),
        Evidence('Reading', '${(reading * 100).round()}%'),
      ],
    );
  }
  if (reading != null && listening != null && reading - listening > 0.15) {
    add(
      LearningTraitKind.strongReader,
      'Reads above listening level — stories are a natural doorway.',
      [
        Evidence('Reading', '${(reading * 100).round()}%'),
        Evidence('Listening', '${(listening * 100).round()}%'),
      ],
    );
  }
  if (speaking != null && others.isNotEmpty && _avg(others) - speaking > 0.2) {
    add(
      LearningTraitKind.avoidsSpeaking,
      'Speaking lags the other skills — likely avoidance, not inability.',
      [
        Evidence('Speaking', '${(speaking * 100).round()}%'),
        Evidence('Other skills', '${(_avg(others) * 100).round()}%'),
      ],
    );
  }

  // Confidence: behavioural, separate from mastery. DNA confidence shifts the
  // baseline; speaking avoidance drags its per-skill confidence below mastery.
  final baseline = dna.contains('lowConfidence')
      ? 0.35
      : dna.contains('highConfidence')
      ? 0.7
      : 0.5;
  final bySkill = <LanguageSkill, double>{};
  for (final e in facts.skills.entries) {
    if (e.value.level == 0) continue;
    var c = (baseline + e.value.level) / 2;
    if (e.key == LanguageSkill.speaking &&
        traits.any((t) => t.kind == LearningTraitKind.avoidsSpeaking)) {
      c *= 0.6;
    }
    bySkill[e.key] = double.parse(c.toStringAsFixed(2));
  }
  final confidence = ConfidenceModel(
    bySkill: bySkill,
    overall: bySkill.isEmpty
        ? baseline
        : double.parse(_avg(bySkill.values).toStringAsFixed(2)),
  );

  // Motivation from streak + mastery trend across history.
  MotivationModel motivation;
  if (history.length < 2) {
    motivation = const MotivationModel(
      state: MotivationState.unknown,
      rationale: 'Not enough sessions yet to read motivation.',
    );
  } else {
    final first = _avg(history.first.mastery.values);
    final last = _avg(history.last.mastery.values);
    final delta = last - first;
    final momentum =
        (delta * 4).clamp(-1.0, 1.0) * (streakDays >= 3 ? 1.0 : 0.6);
    final state = delta > 0.02 && streakDays >= 2
        ? MotivationState.flowing
        : delta < -0.02
        ? MotivationState.strained
        : MotivationState.steady;
    motivation = MotivationModel(
      state: state,
      momentum: double.parse(momentum.toStringAsFixed(2)),
      rationale: switch (state) {
        MotivationState.flowing => 'Mastery rising with a steady streak.',
        MotivationState.strained => 'Mastery slipping — reduce pressure.',
        _ => 'Holding steady.',
      },
    );
  }

  // Speed + tolerance only when the data exists.
  final learningSpeed = facts.totalAnswered < 10
      ? null
      : dna.contains('fastResponder')
      ? 0.8
      : dna.contains('slowButAccurate')
      ? 0.4
      : 0.6;
  final difficultyTolerance = facts.totalAnswered < 10
      ? null
      : dna.contains('strugglesUnderTimePressure') ||
            dna.contains('lowConfidence')
      ? 0.35
      : facts.accuracy >= 0.75
      ? 0.75
      : 0.55;

  return LearningProfile(
    traits: traits,
    confidence: confidence,
    motivation: motivation,
    learningSpeed: learningSpeed,
    difficultyTolerance: difficultyTolerance,
  );
}
