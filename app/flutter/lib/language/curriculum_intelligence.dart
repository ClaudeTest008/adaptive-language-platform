import 'entities.dart';
import 'relationships.dart';
import 'teacher_brain.dart';

/// Curriculum Intelligence Engine (Phase 26). Pure, deterministic, offline.
///
/// The Teacher Brain understands the learner; this engine makes the teacher
/// understand the LANGUAGE — the curriculum as a connected knowledge graph.
/// It reasons OVER the existing `LanguageKnowledgeGraph` (which already
/// carries prerequisites, typed relations, tiers, CEFR levels) plus the brain;
/// it never builds a second graph and stores no learner state. The graph is
/// static language knowledge, not learner data, so there is still exactly one
/// derived source of truth about the learner.

/// A curriculum node viewed through the learner: what it needs, what it
/// unlocks, how hard it is, and how much teaching it is worth right now.
class CurriculumNode {
  const CurriculumNode({
    required this.conceptId,
    required this.name,
    required this.prerequisites,
    required this.successors,
    required this.connections,
    required this.difficulty,
    required this.estimatedEffort,
    required this.teachingValue,
    required this.mastery,
  });

  final String conceptId;
  final String name;
  final List<String> prerequisites;

  /// Concepts this one unlocks (reverse prerequisite / buildsOn edges).
  final List<String> successors;

  /// Typed relation neighbours (family, interference, culture…).
  final List<String> connections;

  /// 0…1 from CEFR band + tier depth.
  final double difficulty;

  /// Rough minutes to work the concept.
  final int estimatedEffort;

  /// 0…1: how valuable teaching this NOW is — unlocks, weakness, connections.
  final double teachingValue;
  final double mastery;
}

/// One stage of a learning journey (a domain the learner is travelling).
class JourneyStage {
  const JourneyStage({
    required this.conceptId,
    required this.name,
    required this.mastery,
    required this.done,
  });

  final String conceptId;
  final String name;
  final double mastery;
  final bool done;
}

/// A learning journey: "we've been working on travel" — a domain travelled in
/// difficulty order, with progress, the current stage and the next milestone.
class LearningJourney {
  const LearningJourney({
    required this.id,
    required this.name,
    required this.stages,
    required this.progress,
    this.currentStage,
    this.milestone,
  });

  final String id;
  final String name;
  final List<JourneyStage> stages;

  /// 0…1 fraction of stages done.
  final double progress;
  final JourneyStage? currentStage;

  /// The next celebration point ("half the journey", "journey complete").
  final String? milestone;
}

const double _knownThreshold = 0.5;

class CurriculumIntelligenceEngine {
  const CurriculumIntelligenceEngine();

  /// The learner-relative view of one concept.
  CurriculumNode node(
    String conceptId,
    LanguageKnowledgeGraph graph,
    TeacherBrain brain,
  ) {
    final n = graph[conceptId];
    final mastery = _mastery(brain, conceptId);
    final successors = <String>[
      for (final other in graph.nodes.values)
        if (other.prerequisites.contains(conceptId)) other.conceptId,
      for (final r in graph.relations)
        if (r.from == conceptId &&
            (r.type == LanguageRelationType.buildsOn))
          r.to,
    ];
    final connections = [
      for (final r in graph.touching(conceptId))
        r.from == conceptId ? r.to : r.from,
    ];
    final cefr = n?.cefr ?? CefrLevel.a1;
    final depth = n == null ? 4 : n.path.length;
    final difficulty =
        ((cefr.index / 5) * 0.7 + (depth.clamp(0, 8) / 8) * 0.3)
            .clamp(0.0, 1.0);
    // Value: unlocking power + how weak it is + how connected it is.
    final value = ((successors.length * 0.15) +
            ((1 - mastery) * 0.5) +
            (connections.length * 0.08))
        .clamp(0.0, 1.0);
    return CurriculumNode(
      conceptId: conceptId,
      name: n?.name ?? conceptId.split(':').last,
      prerequisites: n?.prerequisites ?? const [],
      successors: successors,
      connections: connections,
      difficulty: double.parse(difficulty.toStringAsFixed(2)),
      estimatedEffort: 5 + (difficulty * 15).round(),
      teachingValue: double.parse(value.toStringAsFixed(2)),
      mastery: mastery,
    );
  }

  /// The prerequisite of [conceptId] the learner is missing (weakest first);
  /// null when the ground is ready.
  String? missingPrerequisite(
    String conceptId,
    LanguageKnowledgeGraph graph,
    TeacherBrain brain,
  ) {
    final prereqs = graph[conceptId]?.prerequisites ?? const [];
    String? worst;
    var worstMastery = _knownThreshold;
    for (final p in prereqs) {
      final m = _mastery(brain, p);
      if (m < worstMastery) {
        worstMastery = m;
        worst = p;
      }
    }
    return worst;
  }

  /// The engaged concept blocking the most successors (its unlock list is
  /// large but it is still weak); null when nothing blocks.
  String? blockingConcept(LanguageKnowledgeGraph graph, TeacherBrain brain) {
    String? best;
    var bestScore = 0.0;
    for (final id in brain.connections.nodes.keys) {
      final m = _mastery(brain, id);
      if (m >= _knownThreshold || m <= 0) continue;
      final unlocks = node(id, graph, brain).successors.length;
      final score = unlocks * (1 - m);
      if (score > bestScore) {
        bestScore = score;
        best = id;
      }
    }
    return best;
  }

  /// The concept closest to mastery (0.35…0.8 band, highest first) — the
  /// cheapest win; null when nothing is in the band.
  String? almostMastered(TeacherBrain brain) {
    String? best;
    var bestMastery = 0.35;
    for (final e in brain.connections.nodes.entries) {
      final m = e.value.mastery;
      if (m > bestMastery && m < 0.8) {
        bestMastery = m;
        best = e.key;
      }
    }
    return best;
  }

  /// What to study next: missing prerequisite of the current objective →
  /// blocking concept → almost-mastered → highest-teaching-value frontier.
  String? nextToStudy(LanguageKnowledgeGraph graph, TeacherBrain brain) {
    final focus = brain.objectives.currentConceptId;
    if (focus != null) {
      final missing = missingPrerequisite(focus, graph, brain);
      if (missing != null) return missing;
      if (_mastery(brain, focus) < _knownThreshold) return focus;
    }
    return blockingConcept(graph, brain) ??
        almostMastered(brain) ??
        _frontier(graph, brain);
  }

  String? _frontier(LanguageKnowledgeGraph graph, TeacherBrain brain) {
    // Hidden connections point at unmet neighbours of known ground.
    final hidden = brain.connections.hiddenConnections;
    if (hidden.isEmpty) return null;
    String? best;
    var bestValue = -1.0;
    for (final e in hidden) {
      final target =
          brain.connections.nodes[e.fromId]?.known ?? false ? e.toId : e.fromId;
      final v = node(target, graph, brain).teachingValue;
      if (v > bestValue) {
        bestValue = v;
        best = target;
      }
    }
    return best;
  }

  /// Learning journeys: each engaged domain becomes a journey whose stages
  /// are its concepts in difficulty order. Progress is measured, never
  /// assumed; domains the learner has not touched produce no journey.
  List<LearningJourney> journeys(
    LanguageKnowledgeGraph graph,
    TeacherBrain brain,
  ) {
    final result = <LearningJourney>[];
    for (final cluster in brain.connections.clusters) {
      final stages = [
        for (final id in cluster.memberIds)
          JourneyStage(
            conceptId: id,
            name: brain.connections.nodes[id]?.name ?? id.split(':').last,
            mastery: _mastery(brain, id),
            done: _mastery(brain, id) >= _knownThreshold,
          ),
      ]..sort(
          (a, b) => node(a.conceptId, graph, brain)
              .difficulty
              .compareTo(node(b.conceptId, graph, brain).difficulty),
        );
      if (stages.isEmpty) continue;
      final done = stages.where((s) => s.done).length;
      final progress = done / stages.length;
      final current = stages.where((s) => !s.done).firstOrNull;
      result.add(
        LearningJourney(
          id: cluster.id,
          name: cluster.name,
          stages: stages,
          progress: double.parse(progress.toStringAsFixed(2)),
          currentStage: current,
          milestone: progress >= 1.0
              ? 'Journey complete — celebrate it.'
              : progress >= 0.5
              ? 'Past the halfway mark.'
              : null,
        ),
      );
    }
    result.sort((a, b) => b.progress.compareTo(a.progress));
    return result;
  }

  double _mastery(TeacherBrain brain, String id) =>
      brain.connections.nodes[id]?.mastery ?? 0;
}
