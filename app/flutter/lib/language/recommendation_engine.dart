import 'learning_profile.dart';
import 'teacher_brain.dart';
import 'teacher_memory_engine.dart';

/// Recommendation Engine (Phase 32). Pure, deterministic, offline. Consumes
/// ONLY the Teacher Brain (plus, when available, the longitudinal memory
/// summary) and produces ranked, explainable recommendations — what to do
/// next, why, and how urgent. No persistence, no UI, no providers. It does not
/// duplicate curriculum or memory; every recommendation is derived from
/// measured evidence, and an empty brain yields an empty list.

enum RecommendationKind {
  continueJourney,
  recoverWeakConcept,
  review,
  conversation,
  roleplay,
  reading,
  story,
  mentalModel,
  connection,
  speaking,
  curiosity,
  milestone,
  challenge,
  confidence,
  celebrate,
}

/// One typed, explainable recommendation.
class Recommendation {
  const Recommendation({
    required this.id,
    required this.kind,
    required this.priority,
    required this.reason,
    this.requiredConcepts = const [],
    this.estimatedEffortMin = 5,
    this.expectedValue = 0.5,
    this.blockingPrerequisite,
    this.confidence = 0.5,
    this.urgency = 0.5,
  });

  final String id;
  final RecommendationKind kind;

  /// Lower shows first.
  final int priority;
  final String reason;
  final List<String> requiredConcepts;
  final int estimatedEffortMin;

  /// 0…1 expected long-term learning value.
  final double expectedValue;

  /// A prerequisite that must be handled first, when one blocks this.
  final String? blockingPrerequisite;

  /// 0…1 confidence in the recommendation, from how much evidence backs it.
  final double confidence;

  /// 0…1 how time-sensitive acting on this is.
  final double urgency;
}

double _round(double v) => double.parse(v.clamp(0.0, 1.0).toStringAsFixed(2));

/// Produces the ranked recommendation list. Priority order: recovery →
/// active misconception / memory-recurring → speaking avoidance → journey /
/// connection / mental model → celebrate / curiosity → challenge. Ties break
/// deterministically by urgency, then value, then id.
List<Recommendation> recommend(
  TeacherBrain brain, {
  TeacherMemorySummary? memory,
}) {
  final recs = <Recommendation>[];
  final pedagogy = brain.pedagogy;

  // 0 · Recovery beats everything.
  if (pedagogy?.recoveryMode ?? false) {
    recs.add(Recommendation(
      id: 'recover-mode',
      kind: RecommendationKind.review,
      priority: 0,
      reason: pedagogy!.rationale,
      urgency: 0.95,
      expectedValue: 0.7,
      confidence: 0.8,
    ));
  }

  // 1 · Active misconception → recover the concept, connected.
  final focus = brain.objectives.currentConceptId;
  if (focus != null) {
    recs.add(Recommendation(
      id: 'recover-$focus',
      kind: RecommendationKind.recoverWeakConcept,
      priority: 1,
      reason: 'Clear up ${brain.objectives.current}, tied to what you know.',
      requiredConcepts: [focus],
      urgency: 0.8,
      expectedValue: 0.75,
      confidence: 0.8,
    ));
  }

  // 1 · Memory: a misconception that keeps returning is high value.
  if (memory != null && memory.recurringMisconceptions.isNotEmpty) {
    recs.add(Recommendation(
      id: 'recurring-${memory.recurringMisconceptions.first}',
      kind: RecommendationKind.recoverWeakConcept,
      priority: 1,
      reason:
          '${memory.recurringMisconceptions.first} keeps coming back — worth '
          'fixing for good.',
      requiredConcepts: [memory.recurringMisconceptions.first],
      urgency: 0.85,
      expectedValue: 0.85,
      confidence: 0.9,
    ));
  }

  // 1 · Memory: faded concepts → reconnect (never "you forgot").
  if (memory != null && memory.forgottenSkills.isNotEmpty) {
    recs.add(Recommendation(
      id: 'reconnect-${memory.forgottenSkills.first}',
      kind: RecommendationKind.review,
      priority: 2,
      reason: "Let's reconnect ${memory.forgottenSkills.first} — it's been a "
          'while.',
      requiredConcepts: [memory.forgottenSkills.first],
      urgency: 0.5,
      expectedValue: 0.6,
      confidence: 0.85,
    ));
  }

  // 2 · Motivation strained / confidence declining → protect confidence.
  final strained = brain.profile.motivation.state == MotivationState.strained;
  final decliningConfidence = memory?.confidenceTrend == MemoryTrend.declining;
  if (strained || decliningConfidence) {
    recs.add(Recommendation(
      id: 'confidence',
      kind: RecommendationKind.confidence,
      priority: 1,
      reason: strained
          ? 'Momentum dipped — an easy win to rebuild confidence.'
          : 'Confidence is trending down — ease the pressure.',
      urgency: 0.7,
      expectedValue: 0.5,
      confidence: 0.7,
    ));
  }

  // 2 · Speaking avoidance.
  if (brain.profile.has(LearningTraitKind.avoidsSpeaking)) {
    recs.add(const Recommendation(
      id: 'speaking',
      kind: RecommendationKind.speaking,
      priority: 2,
      reason: 'Speaking lags your other skills — a low-pressure roleplay helps.',
      urgency: 0.6,
      expectedValue: 0.7,
      confidence: 0.7,
    ));
  }

  // 3 · Connections / mental models — the connection-first engine of growth.
  if (brain.connections.suggestions.isNotEmpty) {
    final s = brain.connections.suggestions.first;
    recs.add(Recommendation(
      id: 'connect-${s.anchorId}',
      kind: RecommendationKind.connection,
      priority: 3,
      reason: s.rationale,
      requiredConcepts: [s.anchorId, ...s.relatedIds],
      urgency: 0.4,
      expectedValue: 0.75,
      confidence: 0.75,
    ));
  }
  if (brain.mentalModels.isNotEmpty) {
    recs.add(Recommendation(
      id: 'model-${brain.mentalModels.first.title}',
      kind: RecommendationKind.mentalModel,
      priority: 3,
      reason: brain.mentalModels.first.insight,
      urgency: 0.35,
      expectedValue: 0.7,
      confidence: 0.7,
    ));
  }

  // 3 · Celebrate real recent wins (memory-driven, motivating).
  if (memory != null &&
      memory.recentAchievements.isNotEmpty &&
      memory.learningMomentum > 0) {
    recs.add(Recommendation(
      id: 'celebrate',
      kind: RecommendationKind.celebrate,
      priority: 3,
      reason: 'You have been improving — ${memory.recentAchievements.first} '
          'is coming together.',
      urgency: 0.3,
      expectedValue: 0.4,
      confidence: 0.9,
    ));
  }

  // 4 · Curiosity — a spark, never spam.
  if (brain.curiosities.isNotEmpty) {
    recs.add(Recommendation(
      id: 'curiosity',
      kind: RecommendationKind.curiosity,
      priority: 4,
      reason: brain.curiosities.first.text,
      urgency: 0.25,
      expectedValue: 0.45,
      confidence: 0.6,
    ));
  }

  // 5 · A stretch, when material is running easy and confidence is high.
  if (pedagogy?.difficulty.name == 'tooEasy' &&
      brain.profile.confidence.overall >= 0.7) {
    recs.add(const Recommendation(
      id: 'challenge',
      kind: RecommendationKind.challenge,
      priority: 5,
      reason: "Material is running easy — time to stretch.",
      urgency: 0.3,
      expectedValue: 0.6,
      confidence: 0.6,
    ));
  }

  recs.sort((a, b) {
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;
    final u = b.urgency.compareTo(a.urgency);
    if (u != 0) return u;
    final v = b.expectedValue.compareTo(a.expectedValue);
    if (v != 0) return v;
    return a.id.compareTo(b.id);
  });
  // Normalize the numeric fields for stable output.
  return [
    for (final r in recs)
      Recommendation(
        id: r.id,
        kind: r.kind,
        priority: r.priority,
        reason: r.reason,
        requiredConcepts: r.requiredConcepts,
        estimatedEffortMin: r.estimatedEffortMin,
        expectedValue: _round(r.expectedValue),
        blockingPrerequisite: r.blockingPrerequisite,
        confidence: _round(r.confidence),
        urgency: _round(r.urgency),
      ),
  ];
}

/// The single most important recommendation, or null when the brain affords
/// none (empty/new learner) — never a fabricated default.
Recommendation? topRecommendation(
  TeacherBrain brain, {
  TeacherMemorySummary? memory,
}) {
  final list = recommend(brain, memory: memory);
  return list.isEmpty ? null : list.first;
}
