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

/// Per-word pronunciation feedback: what the learner should have said,
/// what the recognizer heard, and whether it was close enough.
class PronWord {
  const PronWord({required this.target, required this.similarity, this.heard});

  final String target;

  /// Best-matching recognized word (null if nothing matched).
  final String? heard;

  /// 0..1 closeness of [heard] to [target].
  final double similarity;

  bool get ok => similarity >= 0.6;
}

/// Word-level pronunciation result: overall score + per-word detail.
class PronunciationResult {
  const PronunciationResult({required this.score, required this.words});

  final double score;
  final List<PronWord> words;
}

/// Phoneme-aware pronunciation scoring (ADR-0024). Aligns each target
/// word to its closest word in the recognizer transcript and scores by
/// normalized edit distance over phonetically-folded forms — so a near
/// miss ("ambre" for "hambre") scores partial credit, not zero, and the
/// learner sees which word slipped. A speech recognizer rarely returns
/// diacritics, so accents are folded (unlike typed answers).
PronunciationResult scorePronunciationDetailed(String target, String transcript) {
  final want = _tokens(target);
  final got = _tokens(transcript);
  if (want.isEmpty) {
    return const PronunciationResult(score: 0, words: []);
  }
  final remaining = [...got];
  final words = <PronWord>[];
  for (final w in want) {
    // Greedy: take the closest still-unused recognized word.
    var bestSim = 0.0;
    var bestIdx = -1;
    for (var i = 0; i < remaining.length; i++) {
      final sim = _similarity(w, remaining[i]);
      if (sim > bestSim) {
        bestSim = sim;
        bestIdx = i;
      }
    }
    if (bestIdx >= 0 && bestSim >= 0.34) {
      words.add(PronWord(
        target: w,
        heard: remaining.removeAt(bestIdx),
        similarity: bestSim,
      ));
    } else {
      words.add(PronWord(target: w, similarity: 0));
    }
  }
  final score = words.fold(0.0, (s, w) => s + w.similarity) / words.length;
  return PronunciationResult(score: score, words: words);
}

/// Back-compat 0..1 score (used by the signal update).
double scorePronunciation(String target, String transcript) =>
    scorePronunciationDetailed(target, transcript).score;

/// 1 - normalized Levenshtein over phonetically-folded words.
double _similarity(String a, String b) {
  final x = _phonetic(a);
  final y = _phonetic(b);
  if (x.isEmpty && y.isEmpty) return 1;
  final d = _levenshtein(x, y);
  final maxLen = x.length > y.length ? x.length : y.length;
  return maxLen == 0 ? 1 : (1 - d / maxLen).clamp(0.0, 1.0);
}

/// Collapses spelling differences that sound alike in Spanish/English so
/// recognizer quirks don't over-penalize: silent h, b/v, y/ll, qu/k,
/// z/c→s, double letters. A light phoneme approximation.
String _phonetic(String w) {
  var s = _fold(w);
  s = s
      .replaceAll('h', '')
      .replaceAll('v', 'b')
      .replaceAll('ll', 'y')
      .replaceAll('qu', 'k')
      .replaceAll('z', 's')
      .replaceAll('ce', 'se')
      .replaceAll('ci', 'si');
  // Collapse doubled letters.
  final buf = StringBuffer();
  String? prev;
  for (final ch in s.split('')) {
    if (ch != prev) buf.write(ch);
    prev = ch;
  }
  return buf.toString();
}

int _levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var cur = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    cur[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = cur;
    cur = tmp;
  }
  return prev[n];
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
