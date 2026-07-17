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

class Story {
  const Story({
    required this.id,
    required this.title,
    required this.level,
    required this.phrases,
    this.topics = const [],
  });

  final String id;
  final String title;
  final CefrLevel level;
  final List<StoryPhrase> phrases;
  final List<String> topics;

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
