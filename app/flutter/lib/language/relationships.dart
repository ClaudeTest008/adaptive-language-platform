/// Language knowledge graph (ADR-0015): typed relationships between
/// language concepts, projected down onto the UNCHANGED core
/// KnowledgeGraph (ADR-0008) so the adaptive engine consumes language
/// structure without knowing languages exist.
library;

import '../adaptive/graph.dart';
import 'entities.dart';

/// Language-specific relationship types.
enum LanguageRelationType {
  /// Hard prerequisite: target must be mastered first.
  requires,

  /// Soft progression: natural next concept after mastering source.
  buildsOn,

  /// Native-language interference: practicing one triggers errors in the
  /// other (misconception engine input, Phase 2).
  interferesWith,

  /// Concept is only fully understood with this cultural context.
  culturalContext,

  /// Lookalike vocabulary with different meaning (embarazada ≠ embarrassed).
  falseFriend,

  /// Generic semantic association (food → restaurant → ordering).
  relatedTo,
}

class LanguageRelation {
  const LanguageRelation({
    required this.from,
    required this.to,
    required this.type,
    this.note,
  });

  /// Concept ids (LanguageNode.conceptId). `from`/`to` may reference
  /// concepts outside the graph (e.g. a native-language pattern id like
  /// `en:be-adjective` that exists only as an interference source).
  final String from;
  final String to;
  final LanguageRelationType type;

  /// Human explanation, surfaced by the AI tutor,
  /// e.g. "Spanish uses tener for physical states".
  final String? note;
}

class LanguageKnowledgeGraph {
  LanguageKnowledgeGraph(List<LanguageNode> nodeList, this.relations)
    : nodes = {for (final n in nodeList) n.conceptId: n};

  final Map<String, LanguageNode> nodes;
  final List<LanguageRelation> relations;

  LanguageNode? operator [](String conceptId) => nodes[conceptId];

  List<LanguageRelation> ofType(LanguageRelationType type) =>
      [
        for (final r in relations)
          if (r.type == type) r,
      ];

  /// All relations touching [conceptId], either direction.
  List<LanguageRelation> touching(String conceptId) => [
    for (final r in relations)
      if (r.from == conceptId || r.to == conceptId) r,
  ];

  /// Interference sources for a concept — what the misconception engine
  /// checks when a learner errs on it (interferesWith + falseFriend).
  List<LanguageRelation> interference(String conceptId) => [
    for (final r in touching(conceptId))
      if (r.type == LanguageRelationType.interferesWith ||
          r.type == LanguageRelationType.falseFriend)
        r,
  ];

  /// Every node on the lineage of the given skill (per-skill mastery
  /// aggregation input).
  Iterable<LanguageNode> nodesForSkill(LanguageSkill skill) =>
      nodes.values.where((n) => n.skill == skill);

  /// Projects onto the core graph (ADR-0008) — ConceptNode ids are the
  /// language concept ids; the engine's lapse propagation, scheduling and
  /// selection work unchanged. Mapping:
  ///   requires            → prerequisites
  ///   buildsOn            → followUps (and related, both directions)
  ///   everything else     → related (both directions)
  ///   parent lineage      → prerequisite (parent before child)
  KnowledgeGraph toCoreGraph() {
    final prereqs = <String, Set<String>>{};
    final related = <String, Set<String>>{};
    final followUps = <String, Set<String>>{};

    for (final n in nodes.values) {
      prereqs[n.conceptId] = {
        ...n.prerequisites,
        if (n.parent != null) n.parent!.conceptId,
      };
      related[n.conceptId] = {};
      followUps[n.conceptId] = {};
    }
    for (final r in relations) {
      switch (r.type) {
        case LanguageRelationType.requires:
          prereqs.putIfAbsent(r.from, () => {}).add(r.to);
        case LanguageRelationType.buildsOn:
          followUps.putIfAbsent(r.from, () => {}).add(r.to);
          related.putIfAbsent(r.from, () => {}).add(r.to);
          related.putIfAbsent(r.to, () => {}).add(r.from);
        default:
          related.putIfAbsent(r.from, () => {}).add(r.to);
          related.putIfAbsent(r.to, () => {}).add(r.from);
      }
    }

    ConceptType typeFor(LanguageNode? n) => switch (n?.tier) {
      null => ConceptType.tag, // relation endpoint outside the hierarchy
      LanguageTier.language ||
      LanguageTier.level ||
      LanguageTier.skill ||
      LanguageTier.domain ||
      LanguageTier.topic => ConceptType.topic,
      _ => ConceptType.subtopic,
    };

    final ids = {...prereqs.keys, ...related.keys, ...followUps.keys};
    return KnowledgeGraph({
      for (final id in ids)
        id: ConceptNode(
          id: id,
          name: nodes[id]?.name ?? id,
          type: typeFor(nodes[id]),
          prerequisites: (prereqs[id] ?? const {}).toList(),
          related: (related[id] ?? const {}).toList(),
          followUps: (followUps[id] ?? const {}).toList(),
        ),
    });
  }
}
