import 'connections.dart';
import 'misconceptions.dart';

/// Mental Model Builder + Pattern Discovery (Phase 19). The Connection Engine
/// links concepts; this layer turns those links into *understanding* — the
/// short teaching insights a good teacher gives so isolated facts become one
/// idea ("Spanish uses TENER where English uses TO BE").
///
/// Pure, deterministic, offline. It reads only the derived connection graph and
/// misconceptions — it never fabricates learner history. The teaching text is
/// language knowledge (curated, stable), not invented learner data.

/// The kind of intuition a mental model conveys.
enum MentalModelKind { contrast, family, pattern }

/// A teachable "big idea" that ties several concepts together.
class MentalModel {
  const MentalModel({
    required this.title,
    required this.insight,
    required this.anchorConceptId,
    required this.relatedConceptIds,
    required this.kind,
  });

  final String title;
  final String insight;
  final String anchorConceptId;
  final List<String> relatedConceptIds;
  final MentalModelKind kind;
}

/// A structural regularity the learner is (or should be) internalizing.
enum PatternType {
  verbFamily,
  grammarFamily,
  semanticGroup,
  interference,
  falseFriend,
  progression,
}

class LanguagePattern {
  const LanguagePattern({
    required this.type,
    required this.name,
    required this.memberIds,
  });

  final PatternType type;
  final String name;
  final List<String> memberIds;
}

bool _has(String id, String token) => id.contains(token);

String _name(ConnectionGraph g, String id) =>
    g.nodes[id]?.name ?? id.split(':').last;

/// Discovers structural patterns from the connection graph: families from
/// clusters, and typed regularities from relation edges.
List<LanguagePattern> discoverPatterns(ConnectionGraph graph) {
  final patterns = <LanguagePattern>[];
  for (final c in graph.clusters) {
    final isGrammar = _has(c.id, ':grammar:');
    final isVerb = _has(c.id, ':verb');
    patterns.add(
      LanguagePattern(
        type: isVerb
            ? PatternType.verbFamily
            : isGrammar
            ? PatternType.grammarFamily
            : PatternType.semanticGroup,
        name: c.name,
        memberIds: c.memberIds,
      ),
    );
  }
  for (final e in graph.edges) {
    switch (e.type) {
      case ConnectionRelationType.interference:
        patterns.add(
          LanguagePattern(
            type: PatternType.interference,
            name: '${_name(graph, e.fromId)} ↔ ${_name(graph, e.toId)}',
            memberIds: [e.fromId, e.toId],
          ),
        );
      case ConnectionRelationType.falseFriend:
        patterns.add(
          LanguagePattern(
            type: PatternType.falseFriend,
            name: _name(graph, e.fromId),
            memberIds: [e.fromId, e.toId],
          ),
        );
      case ConnectionRelationType.progression:
        patterns.add(
          LanguagePattern(
            type: PatternType.progression,
            name: '${_name(graph, e.fromId)} → ${_name(graph, e.toId)}',
            memberIds: [e.fromId, e.toId],
          ),
        );
      default:
        break;
    }
  }
  return patterns;
}

/// Curated teaching insight for a family cluster, keyed off the concepts it
/// contains. Returns null when no curated model fits (caller falls back to a
/// generic family model). Language knowledge, deterministic — not learner data.
MentalModel? _curatedFor(ConnectionGraph g, LearningCluster c) {
  final ids = c.memberIds;
  final tener = ids.where((id) => _has(id, 'tener')).toList();
  if (tener.length >= 2) {
    return MentalModel(
      title: 'tener, not to be',
      insight:
          'Spanish often uses TENER where English uses TO BE. "Tener hambre" '
          'is literally "to have hunger". Learn these as one family, not '
          'separate phrases.',
      anchorConceptId: tener.first,
      relatedConceptIds: tener,
      kind: MentalModelKind.contrast,
    );
  }
  return null;
}

/// Builds mental models from the connection graph and misconceptions. Curated
/// contrasts come first (por/para, ser/estar, tener), then family models from
/// remaining clusters. Capped so the teacher gives one big idea at a time.
List<MentalModel> buildMentalModels({
  required ConnectionGraph graph,
  List<Misconception> misconceptions = const [],
  int maxModels = 3,
}) {
  final models = <MentalModel>[];
  final ids = graph.nodes.keys.toList();

  bool present(String token) => ids.any((id) => _has(id, token));
  String firstWith(String token) =>
      ids.firstWhere((id) => _has(id, token), orElse: () => '');

  // por vs para — the classic contrast.
  if (present('por') && present('para')) {
    models.add(
      MentalModel(
        title: 'por vs para',
        insight:
            'Think of POR as movement THROUGH — cause, route, duration, '
            'exchange. Think of PARA as direction TOWARD a goal — destination, '
            'purpose, deadline, recipient. You already know destination from '
            '"voy para Madrid".',
        anchorConceptId: firstWith('para'),
        relatedConceptIds: [firstWith('por'), firstWith('para')],
        kind: MentalModelKind.contrast,
      ),
    );
  }

  // ser vs estar.
  if (present('ser') && present('estar')) {
    models.add(
      MentalModel(
        title: 'ser vs estar',
        insight:
            'SER is what something IS — identity, permanent traits. ESTAR is '
            'how something is RIGHT NOW — location and temporary states. Start '
            'from location, which you already know, then extend to feelings.',
        anchorConceptId: firstWith('estar'),
        relatedConceptIds: [firstWith('ser'), firstWith('estar')],
        kind: MentalModelKind.contrast,
      ),
    );
  }

  // Family models from clusters (tener, then generic groups).
  for (final c in graph.clusters) {
    if (models.length >= maxModels) break;
    final curated = _curatedFor(graph, c);
    if (curated != null) {
      models.add(curated);
      continue;
    }
    if (c.memberIds.length >= 3) {
      final names = c.memberIds.map((id) => _name(graph, id)).take(4).join(', ');
      models.add(
        MentalModel(
          title: c.name,
          insight:
              'These belong together: $names. Learning them as one group — '
              'not isolated words — makes each easier to remember.',
          anchorConceptId: c.memberIds.first,
          relatedConceptIds: c.memberIds,
          kind: MentalModelKind.family,
        ),
      );
    }
  }

  return models.take(maxModels).toList();
}
