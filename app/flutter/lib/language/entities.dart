/// Language knowledge hierarchy (ADR-0015). Pure Dart — no Flutter, no
/// Firebase, no imports from the Adaptive Learning Core.
///
/// Language → Level → Skill → Domain → Topic → Grammar Concept →
/// Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation
///
/// Follows the ADR-0012 discipline: nodes exist to mint stable,
/// hierarchical, human-readable concept-id strings that the unchanged
/// adaptive engine already tracks. The engine never sees these types.
library;

/// CEFR proficiency levels plus an escape hatch for custom curricula
/// (e.g. "survival", "business", heritage-speaker tracks).
enum CefrLevel { a1, a2, b1, b2, c1, c2, custom }

/// The ten language skills. Each has independent mastery (ADR-0015).
enum LanguageSkill {
  vocabulary,
  grammar,
  reading,
  writing,
  listening,
  speaking,
  pronunciation,
  conversation,
  culture,
  comprehension,
}

/// Hierarchy tiers, ordered shallow → deep. Tiers may be skipped
/// (a phrase can hang directly off a topic), but children must always
/// sit strictly deeper than their parent — same rule as CurriculumNode.
enum LanguageTier {
  language,
  level,
  skill,
  domain,
  topic,
  grammarConcept,
  vocabularyConcept,
  phrase,
  exampleSentence,
  exercise,
  conversation,
}

/// Exercise types (ROADMAP Phases 2–6; the enum is the contract now,
/// implementations land per phase).
enum ExerciseType {
  multipleChoice,
  fillInBlank,
  translation,
  listening,
  speaking,
  pronunciationScoring,
  sentenceBuilding,
  conversationSimulation,
  readingComprehension,
  writingCorrection,
}

/// A node in the language knowledge hierarchy.
///
/// `conceptId` is what the adaptive engine consumes:
/// `es:a1:grammar:verbs:present-tense:ar-verbs` — hierarchical, stable,
/// human-readable, exactly like ADR-0012 curriculum ids.
class LanguageNode {
  const LanguageNode({
    required this.tier,
    required this.slug,
    required this.name,
    this.parent,
    this.prerequisites = const [],
  });

  final LanguageTier tier;

  /// Short stable identifier segment (kebab-case, or ISO code for the
  /// language tier).
  final String slug;
  final String name;
  final LanguageNode? parent;

  /// Concept-id references (any tier) that should be mastered first.
  final List<String> prerequisites;

  /// Concept id consumed by the learner model / knowledge graph.
  String get conceptId => parent == null ? slug : '${parent!.conceptId}:$slug';

  /// Path from language root down to this node.
  List<LanguageNode> get path =>
      parent == null ? [this] : [...parent!.path, this];

  /// Every ancestor concept id — an answer on this node also exercises
  /// its whole lineage (matches the engine's multi-concept AnswerEvent).
  List<String> get lineageConceptIds => [for (final n in path) n.conceptId];

  /// Nearest skill on the lineage (null above the skill tier).
  LanguageSkill? get skill {
    for (final n in path) {
      if (n.tier == LanguageTier.skill) {
        for (final s in LanguageSkill.values) {
          if (s.name == n.slug) return s;
        }
      }
    }
    return null;
  }

  /// Nearest CEFR level on the lineage (null above the level tier).
  CefrLevel? get cefr {
    for (final n in path) {
      if (n.tier == LanguageTier.level) {
        for (final l in CefrLevel.values) {
          if (l.name == n.slug) return l;
        }
        return CefrLevel.custom;
      }
    }
    return null;
  }

  /// ISO code of the target language (root of the hierarchy).
  String get languageCode => path.first.slug;
}

/// Children must sit strictly deeper than parents; tiers may be skipped.
bool validLanguageHierarchy(LanguageNode node) {
  var current = node;
  while (current.parent != null) {
    if (current.parent!.tier.index >= current.tier.index) return false;
    current = current.parent!;
  }
  return true;
}

// ── Typed nodes for tiers that carry content beyond naming ──────────────

class GrammarConceptNode extends LanguageNode {
  const GrammarConceptNode({
    required super.slug,
    required super.name,
    required this.pattern,
    super.parent,
    super.prerequisites,
    this.explanation,
    this.transferTraps = const [],
  }) : super(tier: LanguageTier.grammarConcept);

  /// The pattern being taught, e.g. "tener + noun for physical states".
  final String pattern;
  final String? explanation;

  /// Known native-language transfer errors this concept attracts,
  /// e.g. "*Yo soy cansado* — English 'to be + adjective' transfer".
  /// Input for the misconception engine (Phase 2).
  final List<String> transferTraps;
}

class VocabularyConceptNode extends LanguageNode {
  const VocabularyConceptNode({
    required super.slug,
    required super.name,
    required this.lemma,
    super.parent,
    super.prerequisites,
    this.translations = const {},
    this.frequencyRank,
  }) : super(tier: LanguageTier.vocabularyConcept);

  final String lemma;

  /// Translations keyed by language code (learner's native language).
  final Map<String, String> translations;

  /// Corpus frequency rank (1 = most frequent); adaptive signal input.
  final int? frequencyRank;
}

class PhraseNode extends LanguageNode {
  const PhraseNode({
    required super.slug,
    required super.name,
    required this.text,
    super.parent,
    super.prerequisites,
    this.translation,
  }) : super(tier: LanguageTier.phrase);

  final String text;
  final String? translation;
}

class ExampleSentenceNode extends LanguageNode {
  const ExampleSentenceNode({
    required super.slug,
    required super.name,
    required this.text,
    super.parent,
    super.prerequisites,
    this.translation,
  }) : super(tier: LanguageTier.exampleSentence);

  final String text;
  final String? translation;
}

class ExerciseNode extends LanguageNode {
  const ExerciseNode({
    required super.slug,
    required super.name,
    required this.exerciseType,
    super.parent,
    super.prerequisites,
  }) : super(tier: LanguageTier.exercise);

  final ExerciseType exerciseType;
}

class ConversationNode extends LanguageNode {
  const ConversationNode({
    required super.slug,
    required super.name,
    required this.scenario,
    super.parent,
    super.prerequisites,
  }) : super(tier: LanguageTier.conversation);

  /// Scenario description handed to the conversation engine / AI tutor,
  /// e.g. "Ordering food at a restaurant; waiter uses A1 vocabulary".
  final String scenario;
}
