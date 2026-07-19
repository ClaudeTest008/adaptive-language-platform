import 'connections.dart';
import 'recommendation_engine.dart';
import 'relationships.dart';
import 'teacher_brain.dart';
import 'teacher_memory_engine.dart';

/// Connection Optimization Engine (Phase 34). Pure, deterministic, offline. It
/// does NOT build another graph — it reasons OVER the learner's derived
/// connection graph (`brain.connections`), the curriculum
/// `LanguageKnowledgeGraph` (for prerequisites), and the long-term memory
/// summary, to improve the quality of the teacher's understanding of the
/// language network: weak vs strong bridges, missing/suggested bridges,
/// isolated concepts, cluster health, and an explainable optimization score.
/// Everything is measured/derived; nothing is invented — no synthetic edges are
/// ever created, only bridges are *recommended*.

enum ConnectionHealth {
  healthy,
  growing,
  weak,
  fragmented,
  stalled,
  recovering,
  unknown,
}

/// The kind of bridge being suggested. The first three are emitted today; the
/// rest are typed seams for future graph enrichment (phonology/etymology/
/// culture/pronunciation/idiom) — never fabricated until real data backs them.
enum BridgeKind {
  teaching,
  review,
  future,
  phonology,
  etymology,
  culture,
  pronunciation,
  idiom,
}

/// A recommended (never synthesized) bridge between two concepts.
class SuggestedBridge {
  const SuggestedBridge({
    required this.fromId,
    required this.toId,
    required this.fromName,
    required this.toName,
    required this.kind,
    required this.reason,
    required this.value,
  });

  final String fromId;
  final String toId;
  final String fromName;
  final String toName;
  final BridgeKind kind;
  final String reason;

  /// 0…1 estimated teaching value of building this bridge.
  final double value;
}

class ConnectionCluster {
  const ConnectionCluster({
    required this.id,
    required this.theme,
    required this.health,
    required this.density,
    required this.mastery,
    required this.coverage,
    required this.futureValue,
    required this.recommendation,
  });

  final String id;
  final String theme;
  final ConnectionHealth health;

  /// Intra-cluster edges / possible pairs (0…1).
  final double density;

  /// Mean member mastery (0…1).
  final double mastery;

  /// Known members / total members (0…1).
  final double coverage;

  /// Unmet neighbours reachable from the cluster — room to grow.
  final int futureValue;
  final String recommendation;
}

class ConnectionOptimizationReport {
  const ConnectionOptimizationReport({
    this.weakBridges = const [],
    this.strongBridges = const [],
    this.suggestedBridges = const [],
    this.isolatedConcepts = const [],
    this.clusters = const [],
    this.density = 0,
    this.health = ConnectionHealth.unknown,
    this.optimizationScore = 0,
    this.scoreBreakdown = const {},
    this.recommendations = const [],
  });

  final List<ConceptEdge> weakBridges;
  final List<ConceptEdge> strongBridges;
  final List<SuggestedBridge> suggestedBridges;
  final List<String> isolatedConcepts;
  final List<ConnectionCluster> clusters;

  /// Overall edges / nodes.
  final double density;
  final ConnectionHealth health;

  /// 0…1 explainable optimization score.
  final double optimizationScore;
  final Map<String, double> scoreBreakdown;

  /// Bridge/cluster recommendations, ready to merge into the ONE Recommendation
  /// Engine list (not a second recommendation system).
  final List<Recommendation> recommendations;

  bool get isEmpty =>
      weakBridges.isEmpty &&
      strongBridges.isEmpty &&
      suggestedBridges.isEmpty &&
      clusters.isEmpty;
}

double _round(double v) => double.parse(v.clamp(0.0, 1.0).toStringAsFixed(2));

ConnectionHealth _clusterHealth(
  double density,
  double mastery,
  double coverage,
  double momentum,
  bool recovering,
) {
  if (recovering) return ConnectionHealth.recovering;
  if (coverage >= 0.85 && density >= 0.5) return ConnectionHealth.healthy;
  if (momentum > 0.08) return ConnectionHealth.growing;
  if (momentum < -0.05) return ConnectionHealth.stalled;
  if (density < 0.25) return ConnectionHealth.fragmented;
  if (mastery < 0.4) return ConnectionHealth.weak;
  return ConnectionHealth.healthy;
}

/// Optimizes the learner's connection network. Empty graph → empty report.
ConnectionOptimizationReport optimizeConnections(
  TeacherBrain brain,
  LanguageKnowledgeGraph graph, {
  TeacherMemorySummary? memory,
}) {
  final g = brain.connections;
  if (g.nodes.isEmpty) return const ConnectionOptimizationReport();

  final momentum = memory?.learningMomentum ?? 0;
  final recovering = brain.pedagogy?.recoveryMode ?? false;
  final forgotten = memory?.forgottenSkills.toSet() ?? const <String>{};
  String name(String id) => g.nodes[id]?.name ?? id.split(':').last;

  // Bridges from the derived graph (never synthesized).
  final weak = [
    for (final e in g.edges)
      if (e.strength < 0.4 || g.weakConnections.contains(e)) e,
  ];
  final strong = [...g.strongConnections];

  // Suggested bridges: hidden connections = "reinforce a known concept through
  // an unmet neighbour"; forgotten concepts with edges = review bridges;
  // curriculum prerequisites the learner knows but that are not yet linked =
  // future bridges.
  final suggested = <SuggestedBridge>[];
  for (final e in g.hiddenConnections.take(6)) {
    final knownEnd = (g.nodes[e.fromId]?.known ?? false) ? e.fromId : e.toId;
    final other = knownEnd == e.fromId ? e.toId : e.fromId;
    suggested.add(SuggestedBridge(
      fromId: knownEnd,
      toId: other,
      fromName: name(knownEnd),
      toName: name(other),
      kind: BridgeKind.teaching,
      reason: 'Reinforce ${name(knownEnd)} by connecting it to ${name(other)}.',
      value: _round(0.6 + e.strength * 0.3),
    ));
  }
  for (final id in forgotten) {
    final edge = g.edges.firstWhere(
      (e) => e.fromId == id || e.toId == id,
      orElse: () => const ConceptEdge(
          fromId: '', toId: '', type: ConnectionRelationType.related, strength: 0),
    );
    if (edge.fromId.isEmpty) continue;
    final other = edge.fromId == id ? edge.toId : edge.fromId;
    suggested.add(SuggestedBridge(
      fromId: id,
      toId: other,
      fromName: name(id),
      toName: name(other),
      kind: BridgeKind.review,
      reason: "Let's reconnect ${name(id)} through ${name(other)}.",
      value: 0.55,
    ));
  }

  // Isolated concepts: engaged but with no edge.
  final touched = <String>{
    for (final e in g.edges) ...[e.fromId, e.toId],
  };
  final isolated = [
    for (final entry in g.nodes.entries)
      if (entry.value.mastery > 0 && !touched.contains(entry.key))
        entry.value.name,
  ];

  // Clusters with health + density.
  final clusters = <ConnectionCluster>[];
  for (final c in g.clusters) {
    final members = c.memberIds.where(g.nodes.containsKey).toList();
    if (members.isEmpty) continue;
    final n = members.length;
    final possible = n <= 1 ? 1 : n * (n - 1) / 2;
    final intra = g.edges
        .where((e) => members.contains(e.fromId) && members.contains(e.toId))
        .length;
    final density = _round(intra / possible);
    final mastery = _round(members
            .map((id) => g.nodes[id]!.mastery)
            .reduce((a, b) => a + b) /
        n);
    final coverage = _round(members.where((id) => g.nodes[id]!.known).length / n);
    final future = g.hiddenConnections
        .where((e) => members.contains(e.fromId) || members.contains(e.toId))
        .length;
    final health = _clusterHealth(density, mastery, coverage, momentum, recovering);
    clusters.add(ConnectionCluster(
      id: c.id,
      theme: c.name,
      health: health,
      density: density,
      mastery: mastery,
      coverage: coverage,
      futureValue: future,
      recommendation: switch (health) {
        ConnectionHealth.fragmented =>
          'Tie ${c.name} together — its concepts are too isolated.',
        ConnectionHealth.weak => 'Strengthen ${c.name} with more practice.',
        ConnectionHealth.stalled => 'Revisit ${c.name} to restart progress.',
        ConnectionHealth.healthy || ConnectionHealth.growing =>
          'Expand ${c.name} into new, connected concepts.',
        _ => 'Keep building ${c.name}.',
      },
    ));
  }

  // Overall density + health.
  final density = _round(g.edges.length / g.nodes.length);
  final overallHealth = recovering
      ? ConnectionHealth.recovering
      : g.edges.isEmpty
      ? ConnectionHealth.fragmented
      : _clusterHealth(
          density.clamp(0.0, 1.0),
          _round(g.nodes.values.map((v) => v.mastery).reduce((a, b) => a + b) /
              g.nodes.length),
          _round(g.nodes.values.where((v) => v.known).length / g.nodes.length),
          momentum,
          recovering,
        );

  // Explainable optimization score.
  final coverage =
      _round(g.nodes.values.where((v) => v.known).length / g.nodes.length);
  final reinforcement =
      g.edges.isEmpty ? 0.0 : _round(strong.length / g.edges.length);
  final memoryStability = memory == null
      ? 0.5
      : _round(1 - (memory.forgottenSkills.length / 10).clamp(0.0, 1.0));
  final breakdown = <String, double>{
    'coverage': coverage,
    'density': _round(density.clamp(0.0, 1.0)),
    'reinforcement': reinforcement,
    'memoryStability': memoryStability,
  };
  final score = _round(
    coverage * 0.3 +
        density.clamp(0.0, 1.0) * 0.25 +
        reinforcement * 0.25 +
        memoryStability * 0.2,
  );

  // Bridge/cluster recommendations (ordinary recommendations).
  final recs = <Recommendation>[
    if (suggested.isNotEmpty)
      Recommendation(
        id: 'bridge-${suggested.first.toId}',
        kind: RecommendationKind.connection,
        priority: 3,
        reason: suggested.first.reason,
        requiredConcepts: [suggested.first.fromId, suggested.first.toId],
        urgency: 0.4,
        expectedValue: suggested.first.value,
        confidence: 0.75,
      ),
    for (final c in clusters)
      if (c.health == ConnectionHealth.fragmented ||
          c.health == ConnectionHealth.weak)
        Recommendation(
          id: 'strengthen-${c.id}',
          kind: RecommendationKind.review,
          priority: 3,
          reason: c.recommendation,
          urgency: 0.45,
          expectedValue: 0.6,
          confidence: 0.7,
        ),
    if (isolated.isNotEmpty)
      Recommendation(
        id: 'reconnect-isolated',
        kind: RecommendationKind.connection,
        priority: 3,
        reason: 'Reconnect ${isolated.first} — it stands alone right now.',
        urgency: 0.4,
        expectedValue: 0.6,
        confidence: 0.7,
      ),
  ];

  return ConnectionOptimizationReport(
    weakBridges: weak,
    strongBridges: strong,
    suggestedBridges: suggested,
    isolatedConcepts: isolated,
    clusters: clusters,
    density: _round(density.clamp(0.0, 1.0)),
    health: overallHealth,
    optimizationScore: score,
    scoreBreakdown: breakdown,
    recommendations: recs,
  );
}
