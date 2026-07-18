import 'book_ingestion.dart';

/// Reading analytics, vocabulary discovery and book relationships (Phase 27).
/// Pure, deterministic, offline. Everything is measured evidence — a value is
/// null when it was never measured, never estimated. These feed the Teacher
/// Brain via reading records; nothing here stores learner state.

/// Measured signals from one reading session.
class ReadingAnalytics {
  const ReadingAnalytics({
    required this.completionPercent,
    required this.chaptersRead,
    this.readingSpeedWpm,
    this.reReadRate,
    this.tapFrequency,
    this.timeSpentMs,
    this.sentenceReplays,
  });

  /// 0…1 fraction of pages reached.
  final double completionPercent;
  final int chaptersRead;

  /// Words per minute; null without a measured duration.
  final double? readingSpeedWpm;

  /// Pages revisited / pages seen; null when not tracked.
  final double? reReadRate;

  /// Word taps per 100 words; null when not tracked.
  final double? tapFrequency;
  final int? timeSpentMs;
  final int? sentenceReplays;
}

/// Computes analytics from measured session inputs. Speed/re-read/tap stay null
/// unless the caller actually measured them.
ReadingAnalytics computeReadingAnalytics({
  required int pagesReached,
  required int totalPages,
  required int chaptersRead,
  int wordsRead = 0,
  int? durationMs,
  int? pagesRevisited,
  int? wordTaps,
  int? sentenceReplays,
}) {
  final completion =
      totalPages == 0 ? 0.0 : (pagesReached / totalPages).clamp(0.0, 1.0);
  return ReadingAnalytics(
    completionPercent: double.parse(completion.toStringAsFixed(2)),
    chaptersRead: chaptersRead,
    readingSpeedWpm: (durationMs == null || durationMs <= 0 || wordsRead == 0)
        ? null
        : double.parse((wordsRead / (durationMs / 60000)).toStringAsFixed(1)),
    reReadRate: pagesRevisited == null || pagesReached == 0
        ? null
        : double.parse((pagesRevisited / pagesReached).toStringAsFixed(2)),
    tapFrequency: wordTaps == null || wordsRead == 0
        ? null
        : double.parse((wordTaps / wordsRead * 100).toStringAsFixed(2)),
    timeSpentMs: durationMs,
    sentenceReplays: sentenceReplays,
  );
}

/// A vocabulary item discovered while reading, with measured history only.
class VocabularyEntry {
  const VocabularyEntry({
    required this.word,
    required this.firstSeenDay,
    required this.lastSeenDay,
    required this.timesEncountered,
    this.timesLookedUp = 0,
    this.sourceBookId,
    this.chapter,
    this.contextSentences = const [],
    this.confidence,
  });

  final String word;
  final String firstSeenDay;
  final String lastSeenDay;
  final int timesEncountered;
  final int timesLookedUp;
  final String? sourceBookId;
  final int? chapter;
  final List<String> contextSentences;

  /// 0…1, only when a real mastery signal exists — otherwise null.
  final double? confidence;

  VocabularyEntry _copy({
    String? lastSeenDay,
    int? timesEncountered,
    int? timesLookedUp,
    List<String>? contextSentences,
    double? confidence,
  }) => VocabularyEntry(
    word: word,
    firstSeenDay: firstSeenDay,
    lastSeenDay: lastSeenDay ?? this.lastSeenDay,
    timesEncountered: timesEncountered ?? this.timesEncountered,
    timesLookedUp: timesLookedUp ?? this.timesLookedUp,
    sourceBookId: sourceBookId,
    chapter: chapter,
    contextSentences: contextSentences ?? this.contextSentences,
    confidence: confidence ?? this.confidence,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'firstSeenDay': firstSeenDay,
    'lastSeenDay': lastSeenDay,
    'timesEncountered': timesEncountered,
    'timesLookedUp': timesLookedUp,
    'sourceBookId': sourceBookId,
    'chapter': chapter,
    'contextSentences': contextSentences,
    'confidence': confidence,
  };

  factory VocabularyEntry.fromJson(Map<String, dynamic> j) => VocabularyEntry(
    word: j['word'] as String,
    firstSeenDay: j['firstSeenDay'] as String,
    lastSeenDay: j['lastSeenDay'] as String,
    timesEncountered: (j['timesEncountered'] as num).toInt(),
    timesLookedUp: (j['timesLookedUp'] as num?)?.toInt() ?? 0,
    sourceBookId: j['sourceBookId'] as String?,
    chapter: (j['chapter'] as num?)?.toInt(),
    contextSentences:
        [...(j['contextSentences'] as List? ?? const []).cast<String>()],
    confidence: (j['confidence'] as num?)?.toDouble(),
  );
}

/// Records an encounter with [word] on [day], merging into any existing entry.
/// Measured counters only — mastery is never invented here.
VocabularyEntry recordEncounter(
  VocabularyEntry? existing, {
  required String word,
  required String day,
  bool lookedUp = false,
  String? context,
  String? bookId,
  int? chapter,
}) {
  if (existing == null) {
    return VocabularyEntry(
      word: word,
      firstSeenDay: day,
      lastSeenDay: day,
      timesEncountered: 1,
      timesLookedUp: lookedUp ? 1 : 0,
      sourceBookId: bookId,
      chapter: chapter,
      contextSentences: context == null ? const [] : [context],
    );
  }
  return existing._copy(
    lastSeenDay: day,
    timesEncountered: existing.timesEncountered + 1,
    timesLookedUp: existing.timesLookedUp + (lookedUp ? 1 : 0),
    contextSentences: context == null || existing.contextSentences.contains(context)
        ? existing.contextSentences
        : [...existing.contextSentences, context].take(5).toList(),
  );
}

/// A compact fingerprint of a book for relationship analysis.
class BookFingerprint {
  const BookFingerprint({
    required this.id,
    required this.title,
    required this.topics,
    required this.words,
  });

  final String id;
  final String title;
  final List<String> topics;
  final Set<String> words;

  factory BookFingerprint.fromIngested(String id, IngestedBook book) =>
      BookFingerprint(
        id: id,
        title: book.title,
        topics: book.topics,
        // Content words only (drop the very frequent 1–2 count noise).
        words: {
          for (final e in book.wordFrequency.entries)
            if (e.key.length > 3 && e.value >= 2) e.key,
        },
      );
}

/// A measured relationship between two books.
class BookRelationship {
  const BookRelationship({
    required this.fromId,
    required this.toId,
    required this.sharedTopics,
    required this.sharedVocabCount,
    required this.strength,
  });

  final String fromId;
  final String toId;
  final List<String> sharedTopics;
  final int sharedVocabCount;

  /// 0…1 blended overlap (topics + vocabulary Jaccard).
  final double strength;
}

/// Relates books by measured topic + vocabulary overlap. No concept graph is
/// duplicated — this is a book-to-book overlap, distinct from the curriculum.
List<BookRelationship> relateBooks(List<BookFingerprint> books) {
  final rels = <BookRelationship>[];
  for (var i = 0; i < books.length; i++) {
    for (var j = i + 1; j < books.length; j++) {
      final a = books[i], b = books[j];
      final sharedTopics = [
        for (final t in a.topics)
          if (b.topics.contains(t)) t,
      ];
      final inter = a.words.intersection(b.words);
      final union = a.words.union(b.words);
      final jaccard = union.isEmpty ? 0.0 : inter.length / union.length;
      final topicScore =
          (a.topics.isEmpty && b.topics.isEmpty) ? 0.0 : sharedTopics.length * 0.2;
      final strength = (topicScore + jaccard).clamp(0.0, 1.0);
      if (strength <= 0) continue;
      rels.add(BookRelationship(
        fromId: a.id,
        toId: b.id,
        sharedTopics: sharedTopics,
        sharedVocabCount: inter.length,
        strength: double.parse(strength.toStringAsFixed(2)),
      ));
    }
  }
  rels.sort((x, y) => y.strength.compareTo(x.strength));
  return rels;
}
