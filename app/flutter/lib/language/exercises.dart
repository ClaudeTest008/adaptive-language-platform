/// Text-first exercise generation (ADR-0017). Pure Dart.
///
/// Exercises are DERIVED from curriculum data — vocabulary, phrases and
/// example sentences already carry everything a text exercise needs
/// (text, translation, concept id). No exercise content is authored or
/// stored separately; the generator is deterministic (seeded by item id)
/// so sessions are reproducible and testable.
library;

import 'dart:math';

import 'entities.dart';
import 'relationships.dart';

class ExerciseItem {
  const ExerciseItem({
    required this.id,
    required this.type,
    required this.node,
    required this.prompt,
    required this.answer,
    this.options = const [],
  });

  final String id;
  final ExerciseType type;

  /// Concept this exercise exercises — its lineage feeds the engine.
  final LanguageNode node;
  final String prompt;

  /// Canonical answer (display form).
  final String answer;

  /// Multiple choice: the choices. Sentence building: the word bank.
  final List<String> options;
}

/// Case-, spacing- and final-punctuation-insensitive comparison.
/// Diacritics are NOT stripped — "esta/está" is a real distinction a
/// language learner must produce.
bool checkAnswer(ExerciseItem item, String given) =>
    _norm(given) == _norm(item.answer);

String _norm(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[.!?¡¿]+$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Generates a deterministic exercise session from the graph.
/// [focusConceptIds] (e.g. a repair block's concepts) sort first so weak
/// material leads the session.
List<ExerciseItem> generateExercises(
  LanguageKnowledgeGraph graph, {
  List<String> focusConceptIds = const [],
  int limit = 10,
}) {
  final vocab = <VocabularyConceptNode>[];
  final phrases = <PhraseNode>[];
  final sentences = <ExampleSentenceNode>[];
  for (final n in graph.nodes.values) {
    switch (n) {
      case VocabularyConceptNode v when v.translations.isNotEmpty:
        vocab.add(v);
      case PhraseNode p when p.translation != null:
        phrases.add(p);
      case ExampleSentenceNode s when s.translation != null:
        sentences.add(s);
      default:
    }
  }
  // Stable base order (map iteration order is insertion order, but sort
  // anyway so generation never depends on curriculum file ordering).
  for (final list in [vocab, phrases, sentences]) {
    list.sort((a, b) => a.conceptId.compareTo(b.conceptId));
  }

  final items = <ExerciseItem>[
    for (final v in vocab) ..._vocabItems(v, vocab),
    for (final p in phrases) ..._phraseItems(p),
    for (final s in sentences) ..._sentenceItems(s, sentences),
  ];

  final focus = focusConceptIds.toSet();
  int rank(ExerciseItem e) =>
      e.node.lineageConceptIds.any(focus.contains) ? 0 : 1;
  items.sort((a, b) {
    final byFocus = rank(a).compareTo(rank(b));
    return byFocus != 0 ? byFocus : a.id.compareTo(b.id);
  });
  // Round-robin across types within each rank group so a session mixes
  // exercise forms instead of clustering all multiple-choice first.
  final result = <ExerciseItem>[];
  for (final group in [
    items.where((e) => rank(e) == 0),
    items.where((e) => rank(e) == 1),
  ]) {
    final byType = <ExerciseType, List<ExerciseItem>>{};
    for (final e in group) {
      byType.putIfAbsent(e.type, () => []).add(e);
    }
    while (byType.isNotEmpty) {
      for (final type in byType.keys.toList()) {
        result.add(byType[type]!.removeAt(0));
        if (byType[type]!.isEmpty) byType.remove(type);
      }
    }
  }
  return result.take(limit).toList();
}

List<ExerciseItem> _vocabItems(
  VocabularyConceptNode v,
  List<VocabularyConceptNode> all,
) {
  final translation = v.translations.values.first;
  final distractors = _shuffled(
    [
      for (final o in all)
        if (o.conceptId != v.conceptId) o.translations.values.first,
    ],
    'mc:${v.conceptId}',
  ).take(3).toList();
  if (distractors.isEmpty) return const [];
  return [
    ExerciseItem(
      id: 'mc:${v.conceptId}',
      type: ExerciseType.multipleChoice,
      node: v,
      prompt: "What does '${v.lemma}' mean?",
      answer: translation,
      options: _shuffled([translation, ...distractors], 'opt:${v.conceptId}'),
    ),
  ];
}

List<ExerciseItem> _phraseItems(PhraseNode p) => [
  ExerciseItem(
    id: 'tr:${p.conceptId}',
    type: ExerciseType.translation,
    node: p,
    prompt: "Translate to ${_targetLanguageName(p)}: '${p.translation}'",
    answer: p.text,
  ),
];

List<ExerciseItem> _sentenceItems(
  ExampleSentenceNode s,
  List<ExampleSentenceNode> all,
) {
  final words = s.text.split(' ');
  final items = <ExerciseItem>[];

  if (words.length >= 2) {
    // Fill in the blank: hide the longest word (usually the content word).
    final target = words.reduce((a, b) => _bare(b).length > _bare(a).length ? b : a);
    items.add(
      ExerciseItem(
        id: 'fib:${s.conceptId}',
        type: ExerciseType.fillInBlank,
        node: s,
        prompt:
            "${s.text.replaceFirst(target, '_____')}\n('${s.translation}')",
        answer: _bare(target),
      ),
    );
    // Sentence building: reorder the shuffled words.
    items.add(
      ExerciseItem(
        id: 'sb:${s.conceptId}',
        type: ExerciseType.sentenceBuilding,
        node: s,
        prompt: "Build the sentence: '${s.translation}'",
        answer: s.text,
        options: _shuffled(words, 'sb:${s.conceptId}'),
      ),
    );
  }

  // Reading comprehension: pick the meaning among other sentences'.
  final distractors = _shuffled(
    [
      for (final o in all)
        if (o.conceptId != s.conceptId) o.translation!,
    ],
    'rc:${s.conceptId}',
  ).take(3).toList();
  if (distractors.isNotEmpty) {
    items.add(
      ExerciseItem(
        id: 'rc:${s.conceptId}',
        type: ExerciseType.readingComprehension,
        node: s,
        prompt: "What does '${s.text}' mean?",
        answer: s.translation!,
        options: _shuffled(
          [s.translation!, ...distractors],
          'rcopt:${s.conceptId}',
        ),
      ),
    );
  }
  return items;
}

String _bare(String word) => word.replaceAll(RegExp(r'[.,!?¡¿]'), '');

String _targetLanguageName(LanguageNode n) => switch (n.languageCode) {
  'es' => 'Spanish',
  'en' => 'English',
  final code => code,
};

/// Deterministic shuffle — same seed string, same order, every run.
List<String> _shuffled(List<String> list, String seed) {
  final copy = [...list];
  copy.shuffle(Random(seed.hashCode));
  return copy;
}
