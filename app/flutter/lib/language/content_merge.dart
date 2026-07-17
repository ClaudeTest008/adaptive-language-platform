/// Content merge (ADR-0026). Pure Dart.
///
/// Closes the ingestion loop: APPROVED Content-Studio candidates
/// (ADR-0025) become live curriculum nodes and story phrases, attached
/// under an "ingested" domain so they never collide with authored
/// concepts. Only approved items flow through — the review queue stays
/// the gate. The Adaptive Learning Core is untouched; this just grows the
/// language graph the projection already consumes.
library;

import 'curriculum.dart';
import 'entities.dart';
import 'ingestion.dart';
import 'relationships.dart';
import 'story.dart';

/// Returns [base] augmented with approved vocabulary / phrase / idiom
/// candidates as new concepts under `<lang>:<level>:vocabulary:ingested`.
/// Sentences are handled separately ([storyFromApproved]). Unchanged when
/// there is nothing approved to add.
Curriculum mergeApprovedContent(
  Curriculum base,
  List<ContentCandidate> approved,
) {
  final words = [
    for (final c in approved)
      if (c.kind == ContentKind.vocabulary && !c.mapped) c,
  ];
  final phrases = [
    for (final c in approved)
      if ((c.kind == ContentKind.phrase || c.kind == ContentKind.idiom) &&
          !c.mapped)
        c,
  ];
  if (words.isEmpty && phrases.isEmpty) return base;

  // Anchor under the existing vocabulary skill; skip if the curriculum
  // has none (defensive — every seed curriculum has one).
  final vocabSkill = base.graph.nodes.values.firstWhere(
    (n) => n.tier == LanguageTier.skill && n.slug == 'vocabulary',
    orElse: () => base.root,
  );
  final domain = LanguageNode(
    tier: LanguageTier.domain,
    slug: 'ingested',
    name: 'Ingested content',
    parent: vocabSkill,
  );

  final added = <LanguageNode>[domain];
  final seen = <String>{for (final n in base.graph.nodes.values) n.conceptId};

  for (final c in words) {
    final node = VocabularyConceptNode(
      slug: _slug(c.text),
      name: c.text,
      lemma: c.text,
      translations: {base.nativeLanguage: c.translation ?? c.text},
      parent: domain,
    );
    if (seen.add(node.conceptId)) added.add(node);
  }
  for (final c in phrases) {
    final node = PhraseNode(
      slug: _slug(c.text),
      name: c.text,
      text: c.text,
      translation: c.translation,
      parent: domain,
    );
    if (seen.add(node.conceptId)) added.add(node);
  }
  if (added.length == 1) return base; // only the empty domain — skip

  return Curriculum(
    languageCode: base.languageCode,
    languageName: base.languageName,
    nativeLanguage: base.nativeLanguage,
    graph: LanguageKnowledgeGraph(
      [...base.graph.nodes.values, ...added],
      base.graph.relations,
    ),
  );
}

/// Builds a story from approved example-sentence candidates, or null when
/// there are fewer than two. Concept ids link back to the ingested
/// domain so reading feeds the graph.
Story? storyFromApproved(
  List<ContentCandidate> approved, {
  required String languageCode,
  required CefrLevel level,
}) {
  final sentences = [
    for (final c in approved)
      if (c.kind == ContentKind.sentence) c,
  ];
  if (sentences.length < 2) return null;
  return Story(
    id: '$languageCode-ingested-story',
    title: 'From your content',
    level: level,
    topics: const ['ingested'],
    phrases: [
      for (final c in sentences)
        StoryPhrase(
          text: c.text,
          translation: c.translation ?? '—',
          conceptIds: [
            if (c.conceptId != null) c.conceptId!,
          ],
        ),
    ],
  );
}

String _slug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ ]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), '-');
