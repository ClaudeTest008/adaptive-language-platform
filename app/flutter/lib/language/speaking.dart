/// Speaking practice (ADR-0020). Pure Dart.
///
/// A speaking drill shows a target (verb form, conjugation, phrase) and
/// the learner pronounces it. A speech recognizer transcribes the
/// attempt; [scorePronunciation] compares transcript to target and yields
/// a 0..1 confidence that feeds `LanguageConceptSignals.pronunciation
/// Confidence`. No audio processing here — recognition is a platform seam.
library;

import 'entities.dart';
import 'relationships.dart';

class SpeakingDrill {
  const SpeakingDrill({
    required this.node,
    required this.target,
    this.translation,
  });

  /// Concept exercised — its lineage feeds the engine + signals.
  final LanguageNode node;

  /// What the learner must say (target language).
  final String target;
  final String? translation;
}

/// Builds a deterministic drill queue from the graph: vocabulary lemmas,
/// phrases and short example sentences are all speakable. [focusConceptIds]
/// (e.g. a repair block) sort first.
List<SpeakingDrill> generateSpeakingDrills(
  LanguageKnowledgeGraph graph, {
  List<String> focusConceptIds = const [],
  int limit = 10,
}) {
  final drills = <SpeakingDrill>[];
  for (final n in graph.nodes.values) {
    switch (n) {
      case VocabularyConceptNode v:
        drills.add(SpeakingDrill(
          node: v,
          target: v.lemma,
          translation: v.translations.values.firstOrNull,
        ));
      case PhraseNode p:
        drills.add(SpeakingDrill(
          node: p,
          target: p.text,
          translation: p.translation,
        ));
      case ExampleSentenceNode s when s.text.split(' ').length <= 6:
        drills.add(SpeakingDrill(
          node: s,
          target: s.text,
          translation: s.translation,
        ));
      default:
    }
  }
  final focus = focusConceptIds.toSet();
  int rank(SpeakingDrill d) =>
      d.node.lineageConceptIds.any(focus.contains) ? 0 : 1;
  drills.sort((a, b) {
    final byFocus = rank(a).compareTo(rank(b));
    return byFocus != 0
        ? byFocus
        : a.node.conceptId.compareTo(b.node.conceptId);
  });
  return drills.take(limit).toList();
}

/// 0..1 pronunciation score: token-level overlap between the recognized
/// transcript and the target, accent- and punctuation-insensitive.
///
/// A speech recognizer rarely returns diacritics reliably, so — unlike
/// typed answers — accents are folded here. This is a proxy for real
/// phoneme scoring (Phase 6 speech models); the seam and signal are what
/// matter now.
double scorePronunciation(String target, String transcript) {
  final want = _tokens(target);
  final got = _tokens(transcript).toSet();
  if (want.isEmpty) return 0;
  final hits = want.where(got.contains).length;
  return hits / want.length;
}

List<String> _tokens(String s) => _fold(s)
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.isNotEmpty)
    .toList();

String _fold(String s) {
  const map = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}
