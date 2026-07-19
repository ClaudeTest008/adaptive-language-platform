import 'curriculum_intelligence.dart';
import 'relationships.dart';
import 'teacher_brain.dart';
import 'teacher_memory_engine.dart';

/// Learning Journey Engine (Phase 32). Pure, deterministic, offline. It does
/// NOT build another graph — it reuses the [CurriculumIntelligenceEngine]'s
/// `journeys` (derived from the existing knowledge graph + brain) and adds
/// health and prediction from measured evidence (mastery, memory momentum,
/// difficulty fit, forgotten skills). A domain with no engaged concepts yields
/// no journey; nothing is fabricated.

enum JourneyHealth {
  healthy,
  recovering,
  plateau,
  stalled,
  accelerating,
  completed,
}

/// Measured predictions for a journey — null fields when unmeasurable.
class JourneyPrediction {
  const JourneyPrediction({
    this.estimatedEffortMin,
    this.nextMilestone,
    this.likelyObstacle,
    this.requiredReview = const [],
  });

  /// Rough minutes to finish the remaining stages (sum of stage efforts).
  final int? estimatedEffortMin;
  final String? nextMilestone;

  /// The hardest remaining stage — the likely sticking point.
  final String? likelyObstacle;

  /// Faded concepts inside this journey that should be reconnected first.
  final List<String> requiredReview;
}

/// A journey with its assessed health and prediction.
class JourneyReport {
  const JourneyReport({
    required this.journey,
    required this.health,
    required this.prediction,
  });

  final LearningJourney journey;
  final JourneyHealth health;
  final JourneyPrediction prediction;
}

/// Assesses every derived journey. Reuses curriculum journeys; layers on
/// health + prediction from the brain and memory summary.
List<JourneyReport> assessJourneys(
  TeacherBrain brain,
  LanguageKnowledgeGraph graph, {
  TeacherMemorySummary? memory,
  CurriculumIntelligenceEngine curriculum =
      const CurriculumIntelligenceEngine(),
}) {
  final journeys = curriculum.journeys(graph, brain);
  final momentum = memory?.learningMomentum ?? 0;
  final forgotten = memory?.forgottenSkills.toSet() ?? const <String>{};

  return [
    for (final j in journeys)
      JourneyReport(
        journey: j,
        health: _health(j, brain, momentum),
        prediction: _predict(j, graph, brain, curriculum, forgotten),
      ),
  ];
}

JourneyHealth _health(
  LearningJourney j,
  TeacherBrain brain,
  double momentum,
) {
  if (j.progress >= 1.0) return JourneyHealth.completed;
  final recovering = brain.pedagogy?.recoveryMode ?? false;
  if (recovering) return JourneyHealth.recovering;
  if (momentum > 0.08) return JourneyHealth.accelerating;
  if (momentum < -0.05) return JourneyHealth.stalled;
  // Mid-progress with flat momentum reads as a plateau; early progress is
  // simply healthy.
  if (j.progress >= 0.35 && momentum.abs() <= 0.02) {
    return JourneyHealth.plateau;
  }
  return JourneyHealth.healthy;
}

JourneyPrediction _predict(
  LearningJourney j,
  LanguageKnowledgeGraph graph,
  TeacherBrain brain,
  CurriculumIntelligenceEngine curriculum,
  Set<String> forgotten,
) {
  final remaining = j.stages.where((s) => !s.done).toList();
  if (remaining.isEmpty) {
    return const JourneyPrediction(nextMilestone: 'Journey complete');
  }
  var effort = 0;
  CurriculumNode? hardest;
  for (final s in remaining) {
    final node = curriculum.node(s.conceptId, graph, brain);
    effort += node.estimatedEffort;
    if (hardest == null || node.difficulty > hardest.difficulty) {
      hardest = node;
    }
  }
  return JourneyPrediction(
    estimatedEffortMin: effort,
    nextMilestone: remaining.first.name,
    likelyObstacle: hardest?.name,
    requiredReview: [
      for (final s in j.stages)
        if (forgotten.contains(s.name) || forgotten.contains(s.conceptId))
          s.name,
    ],
  );
}
