/// Short stories (ADR-0020). Pure Dart — no Flutter, no platform.
///
/// A story is bite-sized reading matched to a CEFR level: an ordered list
/// of phrases, each carrying target text + native translation. Phrases
/// reference concept ids so reading feeds the same knowledge graph and
/// the Today's-Plan recommender. Stories are seed/Content-Intelligence
/// data (assets/stories/), never authored in code.
library;

import 'entities.dart';

class StoryPhrase {
  const StoryPhrase({
    required this.text,
    required this.translation,
    this.conceptIds = const [],
  });

  /// Target-language text, sized to fit one screen line or two.
  final String text;

  /// Native-language translation, shown under the phrase.
  final String translation;

  /// Concepts this phrase exercises (feed the graph / recommender).
  final List<String> conceptIds;
}

/// A highlighted key word from a story: target word + a short gloss.
class StoryVocab {
  const StoryVocab({required this.word, required this.meaning});

  final String word;
  final String meaning;
}

/// A single comprehension check shown after the reading.
class StoryQuestion {
  const StoryQuestion({
    required this.prompt,
    required this.options,
    required this.answerIndex,
  });

  final String prompt;
  final List<String> options;
  final int answerIndex;
}

class Story {
  const Story({
    required this.id,
    required this.title,
    required this.level,
    required this.phrases,
    this.author = '',
    this.topics = const [],
    this.chapterTitles = const [],
    this.chapterStarts = const [],
    this.vocabulary = const [],
    this.questions = const [],
  });

  final String id;
  final String title;
  final CefrLevel level;
  final List<StoryPhrase> phrases;

  /// Original author, for classics (empty for anonymous/original tales).
  final String author;
  final List<String> topics;

  /// Multi-chapter novels: chapter titles + the page index each starts at
  /// (parallel lists; empty for single-chapter stories). Pages flow
  /// continuously through chapters — reading never stops between them.
  final List<String> chapterTitles;
  final List<int> chapterStarts;

  bool get hasChapters => chapterTitles.isNotEmpty;

  /// 0-based chapter for a page index (0 when the story has no chapters).
  int chapterOf(int page) {
    var c = 0;
    for (var i = 0; i < chapterStarts.length; i++) {
      if (page >= chapterStarts[i]) c = i;
    }
    return c;
  }

  /// Rough reading time in minutes from the target-language word count
  /// (~130 wpm for a learner), floored at 1.
  int get readingMinutes {
    final words = phrases.fold(0, (n, p) => n + p.text.split(' ').length);
    return (words / 130).ceil().clamp(1, 99);
  }

  /// Key words worth highlighting while reading (optional).
  final List<StoryVocab> vocabulary;

  /// Comprehension questions shown after the last phrase (optional).
  final List<StoryQuestion> questions;

  /// Whole story as target text — the "Listen to the story" payload.
  String get fullText => phrases.map((p) => p.text).join(' ');

  /// Every concept the story touches (recommendation input).
  Set<String> get conceptIds => {for (final p in phrases) ...p.conceptIds};
}

StoryPhrase _phrase(Map<String, dynamic> p) => StoryPhrase(
      text: p['text'] as String,
      translation: p['translation'] as String,
      conceptIds: [...(p['conceptIds'] as List? ?? const []).cast<String>()],
    );

/// Parses decoded stories JSON: `{ "stories": [ { id, title, level, topics,
/// phrases: [...] } ] }`. Multi-chapter novels use `chapters:
/// [ { title, phrases: [...] } ]` instead of a flat `phrases` list; their
/// pages are flattened so reading flows continuously, with chapter titles
/// and start indexes kept alongside.
List<Story> parseStories(Map<String, dynamic> json) {
  final out = <Story>[];
  for (final raw in (json['stories'] as List? ?? const [])) {
    final map = raw as Map<String, dynamic>;
    final phrases = <StoryPhrase>[];
    final chapterTitles = <String>[];
    final chapterStarts = <int>[];
    final chapters = map['chapters'] as List?;
    if (chapters != null) {
      for (final c in chapters) {
        final cm = c as Map<String, dynamic>;
        chapterTitles.add(cm['title'] as String);
        chapterStarts.add(phrases.length);
        for (final p in (cm['phrases'] as List? ?? const [])) {
          phrases.add(_phrase(p as Map<String, dynamic>));
        }
      }
    } else {
      for (final p in (map['phrases'] as List? ?? const [])) {
        phrases.add(_phrase(p as Map<String, dynamic>));
      }
    }
    out.add(Story(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String? ?? '',
      level: CefrLevel.values.byName(map['level'] as String),
      topics: [...(map['topics'] as List? ?? const []).cast<String>()],
      phrases: phrases,
      chapterTitles: chapterTitles,
      chapterStarts: chapterStarts,
      vocabulary: [
        for (final v in (map['vocabulary'] as List? ?? const []))
          StoryVocab(
            word: (v as Map<String, dynamic>)['word'] as String,
            meaning: v['meaning'] as String,
          ),
      ],
      questions: [
        for (final q in (map['questions'] as List? ?? const []))
          StoryQuestion(
            prompt: (q as Map<String, dynamic>)['prompt'] as String,
            options: [...(q['options'] as List).cast<String>()],
            answerIndex: q['answer'] as int,
          ),
      ],
    ));
  }
  return out;
}

/// Recommends the reading level for a learner. CEFR is the anchor; a
/// learner who is struggling (many weak concepts) is nudged down one
/// level so stories stay comprehensible (i+1, not i+3).
CefrLevel recommendedLevel(
  CefrLevel current, {
  double averageMastery = 1.0,
}) {
  if (averageMastery >= 0.4) return current;
  const order = [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
    CefrLevel.c1,
    CefrLevel.c2,
  ];
  final i = order.indexOf(current);
  return i <= 0 ? CefrLevel.a1 : order[i - 1];
}

/// Stories at or below [level], easiest first — the reading queue.
List<Story> storiesForLevel(List<Story> all, CefrLevel level) {
  const order = [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
    CefrLevel.c1,
    CefrLevel.c2,
  ];
  final cap = order.indexOf(level);
  final matched = [
    for (final s in all)
      if (order.contains(s.level) && order.indexOf(s.level) <= cap) s,
  ]..sort((a, b) => order.indexOf(a.level).compareTo(order.indexOf(b.level)));
  return matched;
}
