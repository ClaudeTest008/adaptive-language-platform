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
    this.topics = const [],
    this.vocabulary = const [],
    this.questions = const [],
  });

  final String id;
  final String title;
  final CefrLevel level;
  final List<StoryPhrase> phrases;
  final List<String> topics;

  /// Key words worth highlighting while reading (optional).
  final List<StoryVocab> vocabulary;

  /// Comprehension questions shown after the last phrase (optional).
  final List<StoryQuestion> questions;

  /// Whole story as target text — the "Listen to the story" payload.
  String get fullText => phrases.map((p) => p.text).join(' ');

  /// Every concept the story touches (recommendation input).
  Set<String> get conceptIds => {for (final p in phrases) ...p.conceptIds};
}

/// Parses decoded stories JSON: `{ "stories": [ { id, title, level,
/// topics, phrases: [ { text, translation, conceptIds } ] } ] }`.
List<Story> parseStories(Map<String, dynamic> json) => [
  for (final raw in (json['stories'] as List? ?? const []))
    Story(
      id: (raw as Map<String, dynamic>)['id'] as String,
      title: raw['title'] as String,
      level: CefrLevel.values.byName(raw['level'] as String),
      topics: [...(raw['topics'] as List? ?? const []).cast<String>()],
      phrases: [
        for (final p in (raw['phrases'] as List? ?? const []))
          StoryPhrase(
            text: (p as Map<String, dynamic>)['text'] as String,
            translation: p['translation'] as String,
            conceptIds:
                [...(p['conceptIds'] as List? ?? const []).cast<String>()],
          ),
      ],
      vocabulary: [
        for (final v in (raw['vocabulary'] as List? ?? const []))
          StoryVocab(
            word: (v as Map<String, dynamic>)['word'] as String,
            meaning: v['meaning'] as String,
          ),
      ],
      questions: [
        for (final q in (raw['questions'] as List? ?? const []))
          StoryQuestion(
            prompt: (q as Map<String, dynamic>)['prompt'] as String,
            options: [...(q['options'] as List).cast<String>()],
            answerIndex: q['answer'] as int,
          ),
      ],
    ),
];

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
