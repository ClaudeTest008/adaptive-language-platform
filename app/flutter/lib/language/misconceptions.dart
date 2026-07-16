/// Misconception engine (ADR-0016). Pure Dart.
///
/// Misconceptions are NOT mistakes: a mistake is a wrong answer; a
/// misconception is a systematic error pattern — typically native-language
/// (L1) interference — that predicts future mistakes until it is taught
/// away. Detection sources:
///   1. `interferesWith` / `falseFriend` relations in the
///      LanguageKnowledgeGraph (authored interference patterns), and
///   2. `GrammarConceptNode.transferTraps` (known transfer errors on the
///      concept itself).
library;

import 'entities.dart';
import 'relationships.dart';

/// One detected misconception, with everything the AI tutor and the
/// lesson planner need to teach it away.
class Misconception {
  const Misconception({
    required this.id,
    required this.conceptId,
    required this.nativeLanguage,
    required this.interferenceSource,
    required this.pattern,
    required this.explanation,
    this.relationType,
    this.relatedConceptIds = const [],
    this.occurrences = 1,
    required this.lastSeen,
  });

  /// Stable: `conceptId|interferenceSource` — repeat detections merge.
  final String id;

  /// Concept the learner erred on.
  final String conceptId;

  /// Learner's native language (interference origin).
  final String nativeLanguage;

  /// What interferes: a concept id (possibly outside the hierarchy, e.g.
  /// `en:be-adjective`) or `trap:<conceptId>` for transfer traps.
  final String interferenceSource;

  /// The pattern being confused, e.g. "tener + noun (hambre, sueño…)".
  final String pattern;

  /// Teachable explanation (relation note or transfer-trap text).
  final String explanation;

  /// Null for transfer traps.
  final LanguageRelationType? relationType;

  /// Concepts to reinforce together (pattern family, contrasts).
  final List<String> relatedConceptIds;

  final int occurrences;
  final DateTime lastSeen;

  Misconception seenAgain(DateTime at) => Misconception(
    id: id,
    conceptId: conceptId,
    nativeLanguage: nativeLanguage,
    interferenceSource: interferenceSource,
    pattern: pattern,
    explanation: explanation,
    relationType: relationType,
    relatedConceptIds: relatedConceptIds,
    occurrences: occurrences + 1,
    lastSeen: at,
  );
}

/// Detects misconceptions on wrong answers using the language graph.
class MisconceptionDetector {
  const MisconceptionDetector(this.graph, {required this.nativeLanguage});

  final LanguageKnowledgeGraph graph;
  final String nativeLanguage;

  /// Empty when [correct] — misconceptions only ever come from errors.
  /// A wrong answer on a concept with no authored interference is a plain
  /// mistake and produces nothing here.
  List<Misconception> detect({
    required List<String> conceptIds,
    required bool correct,
    required DateTime at,
  }) {
    if (correct) return const [];
    final found = <Misconception>[];
    for (final conceptId in conceptIds) {
      final node = graph[conceptId];

      for (final r in graph.interference(conceptId)) {
        final source = r.from == conceptId ? r.to : r.from;
        found.add(
          Misconception(
            id: '$conceptId|$source',
            conceptId: conceptId,
            nativeLanguage: nativeLanguage,
            interferenceSource: source,
            pattern: node is GrammarConceptNode ? node.pattern : node?.name ?? conceptId,
            explanation: r.note ?? 'Interference from $source',
            relationType: r.type,
            relatedConceptIds: _related(conceptId),
            lastSeen: at,
          ),
        );
      }

      if (node is GrammarConceptNode) {
        for (final trap in node.transferTraps) {
          found.add(
            Misconception(
              id: '$conceptId|trap:${node.transferTraps.indexOf(trap)}',
              conceptId: conceptId,
              nativeLanguage: nativeLanguage,
              interferenceSource: 'trap:$conceptId',
              pattern: node.pattern,
              explanation: trap,
              relatedConceptIds: _related(conceptId),
              lastSeen: at,
            ),
          );
        }
      }
    }
    return found;
  }

  /// Pattern family + contrasts: children of the concept (e.g. the tener
  /// phrase family) and relatedTo/buildsOn neighbors.
  List<String> _related(String conceptId) {
    final ids = <String>{};
    for (final n in graph.nodes.values) {
      if (n.parent?.conceptId == conceptId) ids.add(n.conceptId);
    }
    for (final r in graph.touching(conceptId)) {
      if (r.type == LanguageRelationType.relatedTo ||
          r.type == LanguageRelationType.buildsOn) {
        ids.add(r.from == conceptId ? r.to : r.from);
      }
    }
    ids.remove(conceptId);
    return ids.toList();
  }
}

/// Accumulated misconception state for one learner. Immutable; repeat
/// detections merge by id and bump occurrences.
class MisconceptionLog {
  const MisconceptionLog([this.byId = const {}]);

  final Map<String, Misconception> byId;

  List<Misconception> get all {
    final list = byId.values.toList()
      ..sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return list;
  }

  List<Misconception> forConcept(String conceptId) =>
      [for (final m in all) if (m.conceptId == conceptId) m];

  MisconceptionLog record(List<Misconception> detected) {
    if (detected.isEmpty) return this;
    final next = Map<String, Misconception>.of(byId);
    for (final m in detected) {
      final existing = next[m.id];
      next[m.id] = existing == null ? m : existing.seenAgain(m.lastSeen);
    }
    return MisconceptionLog(next);
  }
}

/// Persistence seam (ADR-0015 consequence: contracts land with their
/// first producer). In-memory demo implementation until the Firestore
/// swap (`docs/database/05-language-schema.md`, Phase 8).
abstract class MisconceptionRepository {
  Future<MisconceptionLog> load();
  Future<void> save(MisconceptionLog log);
}
