import 'book_ingestion.dart';
import 'curriculum.dart';
import 'entities.dart';
import 'story.dart';
import 'teacher_brain.dart';

/// Learning Experience Engine (Phase 22) — pure, deterministic, offline.
/// Reading becomes a producer: each finished story yields a measured
/// [ReadingRecord]; vocabulary is mined against the learner's real knowledge;
/// interests are discovered from the topics of books actually read. The brain
/// derives lesson history and interests from these records — records are the
/// captured evidence, the brain remains the single derived source of truth.

/// One word surfaced by vocabulary mining.
class MinedWord {
  const MinedWord({
    required this.word,
    required this.count,
    required this.known,
    this.conceptId,
  });

  final String word;

  /// Occurrences in the text (high-frequency words rank first).
  final int count;

  /// True when the curriculum knows it AND the learner holds it (≥0.5).
  final bool known;
  final String? conceptId;
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u');

/// Mines [text] against the curriculum + the learner's mastery: recurring
/// words first, each marked known/unknown from real data. [minLength] skips
/// grammar particles; [maxWords] bounds the result.
List<MinedWord> mineVocabulary(
  String text,
  Curriculum curriculum,
  Map<String, double> conceptMastery, {
  int minLength = 4,
  int maxWords = 20,
}) {
  final counts = <String, int>{};
  for (final raw in text.toLowerCase().split(RegExp(r'[^a-záéíóúüñ]+'))) {
    if (raw.length < minLength) continue;
    counts[raw] = (counts[raw] ?? 0) + 1;
  }
  final vocabByLemma = <String, VocabularyConceptNode>{
    for (final n in curriculum.graph.nodes.values)
      if (n is VocabularyConceptNode) _fold(n.lemma): n,
  };
  final mined = <MinedWord>[];
  for (final e in counts.entries) {
    final node = vocabByLemma[_fold(e.key)];
    final mastery = node == null ? 0.0 : (conceptMastery[node.conceptId] ?? 0);
    mined.add(
      MinedWord(
        word: e.key,
        count: e.value,
        known: node != null && mastery >= 0.5,
        conceptId: node?.conceptId,
      ),
    );
  }
  mined.sort((a, b) => b.count.compareTo(a.count));
  return mined.take(maxWords).toList();
}

/// The captured evidence of one finished reading session. Persisted; the
/// brain derives outcomes and interests from these.
class ReadingRecord {
  const ReadingRecord({
    required this.day,
    required this.storyId,
    required this.title,
    required this.topics,
    required this.knownRatio,
    required this.unknownWords,
    this.durationMs,
    this.pauseCount,
    this.replays,
    this.pagesRevisited,
    this.wordTaps,
    this.wordsRead,
  });

  final String day;
  final String storyId;
  final String title;
  final List<String> topics;

  /// Fraction of mined words the learner already held — a measured
  /// comprehension proxy.
  final double knownRatio;
  final List<String> unknownWords;

  // Phase 35/38 session measurements — null when the session wasn't
  // instrumented (older records). Measured by the reader UI, never estimated.
  final int? durationMs;
  final int? pauseCount;
  final int? replays;
  final int? pagesRevisited;
  final int? wordTaps;

  /// Words in the finished text — measured from the story itself, so
  /// durationMs + wordsRead give a real reading speed.
  final int? wordsRead;

  Map<String, dynamic> toJson() => {
    'day': day,
    'storyId': storyId,
    'title': title,
    'topics': topics,
    'knownRatio': knownRatio,
    'unknownWords': unknownWords,
    if (durationMs != null) 'durationMs': durationMs,
    if (pauseCount != null) 'pauseCount': pauseCount,
    if (replays != null) 'replays': replays,
    if (pagesRevisited != null) 'pagesRevisited': pagesRevisited,
    if (wordTaps != null) 'wordTaps': wordTaps,
    if (wordsRead != null) 'wordsRead': wordsRead,
  };

  factory ReadingRecord.fromJson(Map<String, dynamic> json) => ReadingRecord(
    day: json['day'] as String,
    storyId: json['storyId'] as String,
    title: (json['title'] as String?) ?? '',
    topics: [...(json['topics'] as List? ?? const []).cast<String>()],
    knownRatio: (json['knownRatio'] as num?)?.toDouble() ?? 0,
    unknownWords:
        [...(json['unknownWords'] as List? ?? const []).cast<String>()],
    durationMs: (json['durationMs'] as num?)?.toInt(),
    pauseCount: (json['pauseCount'] as num?)?.toInt(),
    replays: (json['replays'] as num?)?.toInt(),
    pagesRevisited: (json['pagesRevisited'] as num?)?.toInt(),
    wordTaps: (json['wordTaps'] as num?)?.toInt(),
    wordsRead: (json['wordsRead'] as num?)?.toInt(),
  );
}

/// Builds the record for a finished story from mined vocabulary — every
/// number measured, nothing invented.
ReadingRecord buildReadingRecord({
  required Story story,
  required List<MinedWord> mined,
  required String day,
  int? durationMs,
  int? pauseCount,
  int? replays,
  int? pagesRevisited,
  int? wordTaps,
  int? wordsRead,
}) {
  final unknown = [for (final m in mined) if (!m.known) m.word];
  final knownRatio = mined.isEmpty
      ? 0.0
      : (mined.length - unknown.length) / mined.length;
  return ReadingRecord(
    day: day,
    storyId: story.id,
    title: story.title,
    topics: story.topics,
    knownRatio: double.parse(knownRatio.toStringAsFixed(2)),
    unknownWords: unknown.take(10).toList(),
    durationMs: durationMs,
    pauseCount: pauseCount,
    replays: replays,
    pagesRevisited: pagesRevisited,
    wordTaps: wordTaps,
    wordsRead: wordsRead,
  );
}

/// Derives lesson outcomes for the brain from reading records.
List<LessonOutcome> outcomesFromRecords(List<ReadingRecord> records) => [
  for (final r in records)
    LessonOutcome(
      day: r.day,
      objective: 'Read "${r.title}"',
      score: r.knownRatio,
      confidence: r.knownRatio,
      vocabularyGained: r.unknownWords,
      nextRecommendation: r.unknownWords.isEmpty
          ? null
          : 'Review: ${r.unknownWords.take(3).join(', ')}',
    ),
];

/// Discovers interests from the topics of books the learner actually chose
/// and finished — measured evidence only; empty history means no interests.
List<Interest> discoverInterests(List<ReadingRecord> records) {
  final counts = <String, int>{};
  for (final r in records) {
    for (final t in r.topics) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return const [];
  final max = counts.values.reduce((a, b) => a > b ? a : b);
  final interests = [
    for (final e in counts.entries)
      Interest(e.key, double.parse((e.value / max).toStringAsFixed(2))),
  ]..sort((a, b) => b.weight.compareTo(a.weight));
  return interests.take(6).toList();
}

// ---------- book import (Phase 22) ----------

/// Parses raw content into a [Story]. TXT works today; PDF/EPUB are typed
/// seams awaiting extraction backends — they fail loudly, never silently.
abstract interface class BookImportParser {
  Story parse({required String id, required String title, required List<int> bytes});
}

/// Imports plain text as a readable story: paragraphs become pages, long
/// paragraphs split at sentence boundaries. Translations start empty (mentor
/// support for imported books arrives with the translation seam).
Story importPlainText({
  required String id,
  required String title,
  required String text,
  CefrLevel level = CefrLevel.a2,
  List<String> topics = const [],
  int maxPageChars = 420,
}) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final pages = <String>[];
  for (final p in paragraphs) {
    if (p.length <= maxPageChars) {
      pages.add(p);
      continue;
    }
    final sentences = p.split(RegExp(r'(?<=[.!?…])\s+'));
    var page = StringBuffer();
    for (final s in sentences) {
      if (page.isNotEmpty && page.length + s.length > maxPageChars) {
        pages.add(page.toString().trim());
        page = StringBuffer();
      }
      page.write('$s ');
    }
    if (page.isNotEmpty) pages.add(page.toString().trim());
  }
  return Story(
    id: id,
    title: title,
    level: level,
    topics: topics,
    phrases: [
      for (final p in pages) StoryPhrase(text: p, translation: ''),
    ],
  );
}

/// Builds a rich reader Story from an ingested book (Phase 27): real chapters,
/// paragraph pages, measured difficulty/topics/author — everything the reader
/// and the Teacher Brain consume, derived, nothing fabricated.
Story storyFromIngested({
  required String id,
  required IngestedBook book,
  int maxPageChars = 420,
}) {
  final pages = <String>[];
  final chapterTitles = <String>[];
  final chapterStarts = <int>[];
  for (final chapter in book.chapters) {
    chapterTitles.add(chapter.title);
    chapterStarts.add(pages.length);
    for (final para in chapter.paragraphs) {
      if (para.length <= maxPageChars) {
        pages.add(para);
        continue;
      }
      var page = StringBuffer();
      for (final s in segmentSentences(para)) {
        if (page.isNotEmpty && page.length + s.length > maxPageChars) {
          pages.add(page.toString().trim());
          page = StringBuffer();
        }
        page.write('$s ');
      }
      if (page.isNotEmpty) pages.add(page.toString().trim());
    }
  }
  return Story(
    id: id,
    title: book.title,
    author: book.author,
    level: book.estimatedCefr,
    topics: book.topics,
    chapterTitles: book.chapters.length > 1 ? chapterTitles : const [],
    chapterStarts: book.chapters.length > 1 ? chapterStarts : const [],
    phrases: [
      for (final p in pages)
        if (p.trim().isNotEmpty) StoryPhrase(text: p, translation: ''),
    ],
  );
}
