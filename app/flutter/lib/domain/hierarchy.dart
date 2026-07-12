/// Curriculum hierarchy (ADR-0012):
/// subject → course → module → chapter → topic → subtopic → concept →
/// learning objective. Nodes map onto the ADAPTIVE ENGINE'S EXISTING
/// concept-id strings — the engine stays pure Dart and completely
/// unchanged; hierarchy is a naming discipline over ids it already tracks.
library;

enum CurriculumLevel {
  subject,
  course,
  module,
  chapter,
  topic,
  subtopic,
  concept,
  learningObjective,
}

class CurriculumNode {
  const CurriculumNode({
    required this.level,
    required this.slug,
    required this.name,
    this.parent,
    this.prerequisites = const [],
  });

  final CurriculumLevel level;

  /// Short stable identifier segment (kebab-case).
  final String slug;
  final String name;
  final CurriculumNode? parent;

  /// Concept-id references (any level) that should be mastered first.
  final List<String> prerequisites;

  /// Concept id consumed by the learner model / knowledge graph:
  /// `subject:course:...:slug` — hierarchical, stable, human-readable.
  String get conceptId => parent == null ? slug : '${parent!.conceptId}:$slug';

  /// Path from subject down to this node.
  List<CurriculumNode> get path =>
      parent == null ? [this] : [...parent!.path, this];

  /// Every ancestor concept id — an answer on this node also exercises
  /// its whole lineage (matches the engine's multi-concept AnswerEvent).
  List<String> get lineageConceptIds => [for (final n in path) n.conceptId];
}

/// Validates parent/child level ordering: children must sit strictly
/// deeper than parents (levels may be skipped — a driving-license exam
/// has no "course" tier; a university one does).
bool validHierarchy(CurriculumNode node) {
  var current = node;
  while (current.parent != null) {
    if (current.parent!.level.index >= current.level.index) return false;
    current = current.parent!;
  }
  return true;
}
