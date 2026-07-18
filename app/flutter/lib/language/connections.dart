import 'relationships.dart';

/// The Connection Engine (Phase 18) — teaching through relationships. It
/// derives, from the curriculum's existing knowledge graph and the learner's
/// mastery, a *personal* connection graph: which concepts the learner knows,
/// how they relate, and — most importantly — which nearby concepts are one
/// connection away from what they already understand.
///
/// It is pure, deterministic, and fully offline. It stores nothing new: the
/// graph is derived each time from authoritative state, so it never becomes a
/// second source of truth. A richer (cloud or local LLM) explainer can later
/// consume this same graph without changing it.

/// How two concepts relate, in learner-facing terms. The first group is
/// derived today from curriculum relations and the concept hierarchy; the rest
/// are architectural placeholders for producers that land in later phases
/// (pronunciation patterns, collocations, word formation, …) — never emitted
/// until real data backs them, so no connection is ever fabricated.
enum ConnectionRelationType {
  family, // shares a domain (semantic/grammar group)
  prerequisite, // must be understood first
  progression, // natural next step
  interference, // native-language transfer risk
  falseFriend,
  cultural,
  related,
  // --- future producers (Phase 19+): not emitted yet ---
  cognate,
  collocation,
  idiom,
  pronunciationPattern,
  sentencePattern,
  genderPattern,
  register,
}

ConnectionRelationType _map(LanguageRelationType t) => switch (t) {
  LanguageRelationType.requires => ConnectionRelationType.prerequisite,
  LanguageRelationType.buildsOn => ConnectionRelationType.progression,
  LanguageRelationType.interferesWith => ConnectionRelationType.interference,
  LanguageRelationType.culturalContext => ConnectionRelationType.cultural,
  LanguageRelationType.falseFriend => ConnectionRelationType.falseFriend,
  LanguageRelationType.relatedTo => ConnectionRelationType.related,
};

/// A concept in the learner's personal graph.
class ConceptNode {
  const ConceptNode({
    required this.conceptId,
    required this.name,
    required this.mastery,
    required this.known,
    required this.recentlyActivated,
  });

  final String conceptId;
  final String name;
  final double mastery;

  /// Mastery is at or above the "known" threshold.
  final bool known;

  /// Touched in the current plan / recent activity.
  final bool recentlyActivated;
}

/// A relationship between two concepts, weighted by how well the learner holds
/// both ends. `strength` is 0…1.
class ConceptEdge {
  const ConceptEdge({
    required this.fromId,
    required this.toId,
    required this.type,
    required this.strength,
    this.note,
  });

  final String fromId;
  final String toId;
  final ConnectionRelationType type;
  final double strength;
  final String? note;
}

/// A semantic/grammar group the learner is building (e.g. all `tener +
/// noun` expressions, or a food vocabulary set).
class LearningCluster {
  const LearningCluster({
    required this.id,
    required this.name,
    required this.memberIds,
  });

  final String id;
  final String name;
  final List<String> memberIds;
}

/// A concrete teaching move: "you already know [anchor] — these related
/// concepts are one step away." The unified teacher and notebook use this to
/// teach outward from known ground instead of introducing isolated facts.
class ConnectionSuggestion {
  const ConnectionSuggestion({
    required this.anchorId,
    required this.anchorName,
    required this.relatedIds,
    required this.relatedNames,
    required this.relationType,
    required this.rationale,
  });

  final String anchorId;
  final String anchorName;
  final List<String> relatedIds;
  final List<String> relatedNames;
  final ConnectionRelationType relationType;
  final String rationale;
}

/// The learner's personal connection graph, with the derived views the teacher
/// reasons over.
class ConnectionGraph {
  const ConnectionGraph({
    this.nodes = const {},
    this.edges = const [],
    this.clusters = const [],
    this.recentlyActivated = const [],
    this.strongConnections = const [],
    this.weakConnections = const [],
    this.hiddenConnections = const [],
    this.suggestions = const [],
  });

  final Map<String, ConceptNode> nodes;
  final List<ConceptEdge> edges;
  final List<LearningCluster> clusters;
  final List<String> recentlyActivated;

  /// Both ends known and well held — the learner's solid ground.
  final List<ConceptEdge> strongConnections;

  /// Both ends engaged but at least one is shaky — reinforce.
  final List<ConceptEdge> weakConnections;

  /// One end known, the other not yet met — the teaching frontier.
  final List<ConceptEdge> hiddenConnections;

  /// Ranked teaching moves built from the hidden connections.
  final List<ConnectionSuggestion> suggestions;
}

/// The domain-tier ancestor id of a concept (`es:a1:grammar:verbs` for
/// `es:a1:grammar:verbs:states:tener-states`). Used to group families.
String domainAncestor(String conceptId) {
  final segs = conceptId.split(':');
  return segs.length >= 4 ? segs.take(4).join(':') : conceptId;
}

String _lastSeg(String id) => id.split(':').last;

double _mean(double a, double b) => (a + b) / 2;

/// Builds the learner's connection graph from curriculum [relations] and
/// [conceptMastery]. [recentlyActivated] flags concepts touched in the current
/// plan. Concepts with mastery ≥ [knownThreshold] count as "known".
ConnectionGraph buildConnectionGraph({
  required List<LanguageRelation> relations,
  required Map<String, String> conceptNames,
  required Map<String, double> conceptMastery,
  Set<String> recentlyActivated = const {},
  double knownThreshold = 0.5,
  int maxEdges = 60,
}) {
  double masteryOf(String id) => conceptMastery[id] ?? 0;
  bool isConcept(String id) => conceptNames.containsKey(id);

  // Node set: every engaged concept, plus graph neighbours of engaged
  // concepts (so the teaching frontier has nodes to point at). Native-only
  // interference ids (not real concepts) are excluded.
  final ids = <String>{
    for (final e in conceptMastery.entries)
      if (e.value > 0 && isConcept(e.key)) e.key,
  };
  for (final r in relations) {
    final fromEngaged = masteryOf(r.from) > 0;
    final toEngaged = masteryOf(r.to) > 0;
    if (fromEngaged && isConcept(r.to)) ids.add(r.to);
    if (toEngaged && isConcept(r.from)) ids.add(r.from);
  }

  final nodes = {
    for (final id in ids)
      id: ConceptNode(
        conceptId: id,
        name: conceptNames[id] ?? _lastSeg(id),
        mastery: masteryOf(id),
        known: masteryOf(id) >= knownThreshold,
        recentlyActivated: recentlyActivated.contains(id),
      ),
  };

  final edges = <ConceptEdge>[];

  // Relation edges from the curriculum graph.
  for (final r in relations) {
    if (!ids.contains(r.from) || !ids.contains(r.to)) continue;
    edges.add(
      ConceptEdge(
        fromId: r.from,
        toId: r.to,
        type: _map(r.type),
        strength: _mean(masteryOf(r.from), masteryOf(r.to)),
        note: r.note,
      ),
    );
  }

  // Family edges + clusters from the concept hierarchy: engaged concepts that
  // share a domain belong together. Star-connect each group to its strongest
  // member to keep the graph bounded.
  final byDomain = <String, List<String>>{};
  for (final id in ids) {
    byDomain.putIfAbsent(domainAncestor(id), () => []).add(id);
  }
  final clusters = <LearningCluster>[];
  for (final entry in byDomain.entries) {
    final members = entry.value;
    if (members.length < 2) continue;
    clusters.add(
      LearningCluster(
        id: entry.key,
        name: conceptNames[entry.key] ?? _lastSeg(entry.key),
        memberIds: members,
      ),
    );
    members.sort((a, b) => masteryOf(b).compareTo(masteryOf(a)));
    final anchor = members.first;
    for (final m in members.skip(1)) {
      edges.add(
        ConceptEdge(
          fromId: anchor,
          toId: m,
          type: ConnectionRelationType.family,
          strength: _mean(masteryOf(anchor), masteryOf(m)),
        ),
      );
    }
  }

  edges.sort((a, b) => b.strength.compareTo(a.strength));
  final bounded = edges.take(maxEdges).toList();

  bool known(String id) => masteryOf(id) >= knownThreshold;
  bool engaged(String id) => masteryOf(id) > 0;

  final strong = <ConceptEdge>[];
  final weak = <ConceptEdge>[];
  final hidden = <ConceptEdge>[];
  for (final e in bounded) {
    final kf = known(e.fromId), kt = known(e.toId);
    final ef = engaged(e.fromId), et = engaged(e.toId);
    if (kf && kt) {
      strong.add(e);
    } else if (kf != kt && (!ef || !et)) {
      hidden.add(e); // one end known, the other not yet met
    } else if (ef && et) {
      weak.add(e);
    }
  }

  // Teaching moves: for each known anchor, gather the concepts it connects to
  // that the learner has not met. Rank by how many hang off one anchor.
  final byAnchor = <String, List<String>>{};
  final relByAnchor = <String, ConnectionRelationType>{};
  for (final e in hidden) {
    final anchorId = known(e.fromId) ? e.fromId : e.toId;
    final targetId = known(e.fromId) ? e.toId : e.fromId;
    byAnchor.putIfAbsent(anchorId, () => []).add(targetId);
    relByAnchor.putIfAbsent(anchorId, () => e.type);
  }
  final suggestions =
      byAnchor.entries.map((e) {
        final anchorName = nodes[e.key]?.name ?? _lastSeg(e.key);
        final relatedNames = e.value
            .map((id) => nodes[id]?.name ?? _lastSeg(id))
            .take(4)
            .toList();
        return ConnectionSuggestion(
          anchorId: e.key,
          anchorName: anchorName,
          relatedIds: e.value.take(4).toList(),
          relatedNames: relatedNames,
          relationType: relByAnchor[e.key] ?? ConnectionRelationType.related,
          rationale:
              'You already know $anchorName — '
              '${relatedNames.join(', ')} are closely connected. '
              'Let’s build from what you know.',
        );
      }).toList()
        ..sort((a, b) => b.relatedIds.length.compareTo(a.relatedIds.length));

  return ConnectionGraph(
    nodes: nodes,
    edges: bounded,
    clusters: clusters,
    recentlyActivated: recentlyActivated.toList(),
    strongConnections: strong,
    weakConnections: weak,
    hiddenConnections: hidden,
    suggestions: suggestions,
  );
}

/// Reading-tap architecture (producer wires later): explain [conceptId] using
/// a concept the learner already knows, instead of a bare definition. Returns
/// null when nothing known is connected, so the caller can fall back.
String? explainByConnection(String conceptId, ConnectionGraph graph) {
  final target = graph.nodes[conceptId];
  for (final e in graph.edges) {
    if (e.fromId != conceptId && e.toId != conceptId) continue;
    final otherId = e.fromId == conceptId ? e.toId : e.fromId;
    final other = graph.nodes[otherId];
    if (other != null && other.known) {
      final name = target?.name ?? _lastSeg(conceptId);
      return 'You already know ${other.name}. '
          '$name is closely connected to it.';
    }
  }
  return null;
}
