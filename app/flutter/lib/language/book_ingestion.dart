import 'entities.dart';

/// Book Ingestion Engine (Phase 27). Pure, deterministic, offline, reusable
/// infrastructure — NOTHING learner-specific. It normalizes imported text into
/// a structured book: chapters, paragraphs, sentences, a word index with
/// frequencies, extracted phrases, an estimated reading difficulty (CEFR), and
/// inferred topics. The result feeds the reading library and, once read,
/// becomes measured evidence for the Teacher Brain — but this engine itself
/// knows nothing about any learner.

/// One chapter of an ingested book.
class IngestedChapter {
  const IngestedChapter({
    required this.title,
    required this.paragraphs,
  });

  final String title;
  final List<String> paragraphs;

  List<String> get sentences => [
    for (final p in paragraphs) ...segmentSentences(p),
  ];
}

/// The structured result of ingesting a book.
class IngestedBook {
  const IngestedBook({
    required this.title,
    required this.author,
    required this.language,
    required this.chapters,
    required this.wordFrequency,
    required this.phrases,
    required this.difficulty,
    required this.estimatedCefr,
    required this.topics,
  });

  final String title;
  final String author;

  /// Best-guess language code ('es'/'en'), or '' when undetermined.
  final String language;
  final List<IngestedChapter> chapters;

  /// Lemma-ish word → count across the whole book (lowercased).
  final Map<String, int> wordFrequency;

  /// Frequent multi-word expressions (bigrams), most frequent first.
  final List<String> phrases;

  /// 0…1 reading difficulty.
  final double difficulty;
  final CefrLevel estimatedCefr;
  final List<String> topics;

  int get wordCount => wordFrequency.values.fold(0, (a, b) => a + b);
  int get chapterCount => chapters.length;
}

final _chapterHeading = RegExp(
  r'^\s*(chapter|cap[íi]tulo)\s+([0-9]+|[ivxlcdm]+|\w+)\b.*$',
  caseSensitive: false,
  multiLine: true,
);
final _sentenceSplit = RegExp(r'(?<=[.!?…])\s+');
final _wordSplit = RegExp(r"[^a-záéíóúüñA-ZÁÉÍÓÚÜÑ']+");

/// Splits a paragraph into sentences, keeping terminal punctuation.
List<String> segmentSentences(String paragraph) => [
  for (final s in paragraph.split(_sentenceSplit))
    if (s.trim().isNotEmpty) s.trim(),
];

/// Splits raw text into chapters at "Chapter N" / "Capítulo N" headings. When
/// there are no headings the whole text is one chapter.
List<IngestedChapter> splitChapters(String text) {
  final matches = _chapterHeading.allMatches(text).toList();
  List<String> paras(String body) => [
    for (final p in body.split(RegExp(r'\n\s*\n')))
      if (p.replaceAll(RegExp(r'\s+'), ' ').trim().isNotEmpty)
        p.replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
  if (matches.isEmpty) {
    final p = paras(text);
    return p.isEmpty ? const [] : [IngestedChapter(title: 'Chapter 1', paragraphs: p)];
  }
  final chapters = <IngestedChapter>[];
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
    final title = m.group(0)!.trim();
    final body = text.substring(m.end, end);
    chapters.add(IngestedChapter(title: title, paragraphs: paras(body)));
  }
  return chapters;
}

const _esWords = {
  'el', 'la', 'los', 'las', 'de', 'que', 'y', 'en', 'un', 'una', 'es',
  'por', 'para', 'con', 'no', 'se', 'su', 'tiene', 'pero',
};
const _enWords = {
  'the', 'of', 'and', 'to', 'in', 'is', 'was', 'that', 'for', 'with',
  'you', 'this', 'but', 'have', 'not', 'are',
};

/// Detects the dominant language from function-word hits.
String detectLanguage(Iterable<String> words) {
  var es = 0, en = 0;
  for (final w in words) {
    if (_esWords.contains(w)) es++;
    if (_enWords.contains(w)) en++;
  }
  if (es == 0 && en == 0) return '';
  return es >= en ? 'es' : 'en';
}

const _topicLexicon = <String, List<String>>{
  'travel': ['viaje', 'aeropuerto', 'hotel', 'maleta', 'tren', 'travel', 'airport', 'hotel'],
  'food': ['comida', 'comer', 'restaurante', 'receta', 'food', 'eat', 'recipe'],
  'family': ['familia', 'madre', 'padre', 'hijo', 'family', 'mother', 'father'],
  'nature': ['bosque', 'árbol', 'mar', 'montaña', 'forest', 'tree', 'sea'],
  'work': ['trabajo', 'oficina', 'jefe', 'work', 'office', 'boss'],
  'technology': ['ordenador', 'internet', 'software', 'computer'],
};

/// Infers topics by matching the word index against a small lexicon.
List<String> inferTopics(Map<String, int> wordFrequency, {int max = 4}) {
  final scores = <String, int>{};
  for (final e in _topicLexicon.entries) {
    var s = 0;
    for (final kw in e.value) {
      s += wordFrequency[kw] ?? 0;
    }
    if (s > 0) scores[e.key] = s;
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(max)) e.key];
}

/// Estimates difficulty (0…1) from average word length and sentence length —
/// a deterministic readability proxy — and maps it to a CEFR band.
({double difficulty, CefrLevel cefr}) estimateDifficulty(
  List<String> sentences,
) {
  if (sentences.isEmpty) {
    return (difficulty: 0, cefr: CefrLevel.a1);
  }
  var words = 0, chars = 0;
  for (final s in sentences) {
    final w = s.split(_wordSplit).where((x) => x.isNotEmpty).toList();
    words += w.length;
    chars += w.fold(0, (a, b) => a + b.length);
  }
  final avgWordLen = words == 0 ? 0.0 : chars / words;
  final avgSentLen = words / sentences.length;
  // Normalize: 4-char words + 8-word sentences ≈ easy; 7-char + 22-word ≈ hard.
  final d = (((avgWordLen - 4) / 3) * 0.5 + ((avgSentLen - 8) / 14) * 0.5)
      .clamp(0.0, 1.0);
  final cefr = d < 0.2
      ? CefrLevel.a1
      : d < 0.4
      ? CefrLevel.a2
      : d < 0.6
      ? CefrLevel.b1
      : d < 0.8
      ? CefrLevel.b2
      : CefrLevel.c1;
  return (difficulty: double.parse(d.toStringAsFixed(2)), cefr: cefr);
}

/// Frequent bigrams (excluding pure function-word pairs), most frequent first.
List<String> extractPhrases(List<String> sentences, {int max = 20}) {
  final counts = <String, int>{};
  for (final s in sentences) {
    final words = s
        .toLowerCase()
        .split(_wordSplit)
        .where((w) => w.length > 2)
        .toList();
    for (var i = 0; i + 1 < words.length; i++) {
      final a = words[i], b = words[i + 1];
      if (_esWords.contains(a) && _esWords.contains(b)) continue;
      if (_enWords.contains(a) && _enWords.contains(b)) continue;
      final bigram = '$a $b';
      counts[bigram] = (counts[bigram] ?? 0) + 1;
    }
  }
  final ranked = counts.entries.where((e) => e.value >= 2).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(max)) e.key];
}

/// Ingests raw book [text] into a structured [IngestedBook]. Deterministic;
/// no learner data.
IngestedBook ingestBook({
  required String title,
  required String author,
  required String text,
}) {
  final chapters = splitChapters(text);
  final allSentences = [for (final c in chapters) ...c.sentences];
  final wordFrequency = <String, int>{};
  for (final s in allSentences) {
    for (final w in s.toLowerCase().split(_wordSplit)) {
      if (w.length < 2) continue;
      wordFrequency[w] = (wordFrequency[w] ?? 0) + 1;
    }
  }
  final diff = estimateDifficulty(allSentences);
  return IngestedBook(
    title: title,
    author: author,
    language: detectLanguage(wordFrequency.keys),
    chapters: chapters,
    wordFrequency: wordFrequency,
    phrases: extractPhrases(allSentences),
    difficulty: diff.difficulty,
    estimatedCefr: diff.cefr,
    topics: inferTopics(wordFrequency),
  );
}
