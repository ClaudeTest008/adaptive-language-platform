/// CEFR-aligned curriculum loader (ADR-0015). Parses curriculum JSON
/// (schema: assets/curriculum/curriculum.schema.json) into a
/// LanguageKnowledgeGraph. Pure Dart.
library;

import 'entities.dart';
import 'relationships.dart';

class Curriculum {
  const Curriculum({
    required this.languageCode,
    required this.languageName,
    required this.nativeLanguage,
    required this.graph,
  });

  final String languageCode;
  final String languageName;

  /// Learner's native language (interference/translation reference).
  final String nativeLanguage;
  final LanguageKnowledgeGraph graph;

  LanguageNode get root => graph[languageCode]!;
}

/// Parses decoded curriculum JSON. Nodes must be listed parents-first;
/// `parent` is a full concept id. Throws [FormatException] on unknown
/// tiers, missing parents, or tier-order violations.
Curriculum parseCurriculum(Map<String, dynamic> json) {
  final lang = json['language'] as Map<String, dynamic>;
  final code = lang['code'] as String;
  final root = LanguageNode(
    tier: LanguageTier.language,
    slug: code,
    name: lang['name'] as String,
  );

  final byId = <String, LanguageNode>{code: root};
  for (final raw in (json['nodes'] as List? ?? const [])) {
    final n = raw as Map<String, dynamic>;
    final node = _node(n, byId);
    if (!validLanguageHierarchy(node)) {
      throw FormatException(
        'tier order violation at ${node.conceptId} (${node.tier.name} under '
        '${node.parent?.tier.name})',
      );
    }
    byId[node.conceptId] = node;
  }

  final relations = [
    for (final raw in (json['relations'] as List? ?? const []))
      LanguageRelation(
        from: (raw as Map<String, dynamic>)['from'] as String,
        to: raw['to'] as String,
        type: LanguageRelationType.values.byName(raw['type'] as String),
        note: raw['note'] as String?,
      ),
  ];

  return Curriculum(
    languageCode: code,
    languageName: lang['name'] as String,
    nativeLanguage: json['nativeLanguage'] as String,
    graph: LanguageKnowledgeGraph(byId.values.toList(), relations),
  );
}

LanguageNode _node(Map<String, dynamic> n, Map<String, LanguageNode> byId) {
  final tier = LanguageTier.values.byName(n['tier'] as String);
  final parentId = n['parent'] as String?;
  final parent = parentId == null ? null : byId[parentId];
  if (parentId != null && parent == null) {
    throw FormatException('unknown parent $parentId (parents must be '
        'listed before children)');
  }
  final slug = n['slug'] as String;
  final name = n['name'] as String;
  final prereqs = [...(n['prerequisites'] as List? ?? const []).cast<String>()];

  return switch (tier) {
    LanguageTier.grammarConcept => GrammarConceptNode(
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
      pattern: n['pattern'] as String,
      explanation: n['explanation'] as String?,
      transferTraps:
          [...(n['transferTraps'] as List? ?? const []).cast<String>()],
    ),
    LanguageTier.vocabularyConcept => VocabularyConceptNode(
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
      lemma: n['lemma'] as String,
      translations:
          {...(n['translations'] as Map? ?? const {}).cast<String, String>()},
      frequencyRank: n['frequencyRank'] as int?,
    ),
    LanguageTier.phrase => PhraseNode(
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
      text: n['text'] as String,
      translation: n['translation'] as String?,
    ),
    LanguageTier.exampleSentence => ExampleSentenceNode(
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
      text: n['text'] as String,
      translation: n['translation'] as String?,
    ),
    LanguageTier.exercise => ExerciseNode(
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
      exerciseType: ExerciseType.values.byName(n['exerciseType'] as String),
    ),
    LanguageTier.conversation => ConversationNode(
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
      scenario: n['scenario'] as String,
    ),
    _ => LanguageNode(
      tier: tier,
      slug: slug,
      name: name,
      parent: parent,
      prerequisites: prereqs,
    ),
  };
}
