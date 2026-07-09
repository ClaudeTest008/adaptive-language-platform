/// Knowledge graph (ADR-0008): concept nodes derived from content.
/// Node ids double as concept ids in the learner model.
library;

import '../domain/models.dart';

enum ConceptType { topic, subtopic, tag }

class ConceptNode {
  const ConceptNode({
    required this.id,
    required this.name,
    required this.type,
    this.prerequisites = const [],
    this.related = const [],
    this.followUps = const [],
  });

  final String id;
  final String name;
  final ConceptType type;
  final List<String> prerequisites;
  final List<String> related;
  final List<String> followUps;
}

class KnowledgeGraph {
  const KnowledgeGraph(this.nodes);

  final Map<String, ConceptNode> nodes;

  ConceptNode? operator [](String id) => nodes[id];

  /// Neighbors that should receive reinforcement when [conceptId] is
  /// answered incorrectly.
  List<String> relatedTo(String conceptId) =>
      nodes[conceptId]?.related ?? const [];
}

/// Concepts a question exercises: primary topic first, then subtopic and
/// tags. Every question references at least its topic node.
List<String> conceptsForQuestion(Question q) => [
  q.topicId,
  if (q.subtopic != null) 'sub:${q.topicId}:${q.subtopic}',
  for (final t in q.tags) 'tag:$t',
];

/// Builds the graph from current content. Structure today: topics are
/// root nodes; subtopics hang off their topic (topic = prerequisite);
/// tags shared by questions in multiple topics relate those topics.
/// Explicit prerequisite/follow-up authoring arrives with the Content
/// Studio graph editor (deferred — docs/product/07).
KnowledgeGraph buildKnowledgeGraph(
  List<Topic> topics,
  List<Question> questions,
) {
  final nodes = <String, ConceptNode>{};
  final topicTags = <String, Set<String>>{};
  final subtopicsByTopic = <String, Set<String>>{};

  for (final q in questions) {
    topicTags.putIfAbsent(q.topicId, () => {}).addAll(q.tags);
    if (q.subtopic != null) {
      subtopicsByTopic.putIfAbsent(q.topicId, () => {}).add(q.subtopic!);
    }
  }

  // Tag nodes; a tag relates every topic that uses it.
  final topicsByTag = <String, Set<String>>{};
  for (final e in topicTags.entries) {
    for (final tag in e.value) {
      topicsByTag.putIfAbsent(tag, () => {}).add(e.key);
    }
  }
  for (final e in topicsByTag.entries) {
    nodes['tag:${e.key}'] = ConceptNode(
      id: 'tag:${e.key}',
      name: e.key,
      type: ConceptType.tag,
      related: e.value.toList(),
    );
  }

  for (final t in topics) {
    final subIds = [
      for (final s in subtopicsByTopic[t.id] ?? const <String>{})
        'sub:${t.id}:$s',
    ];
    // Topics sharing a tag are related.
    final relatedTopics = <String>{
      for (final tag in topicTags[t.id] ?? const <String>{})
        ...?topicsByTag[tag],
    }..remove(t.id);
    nodes[t.id] = ConceptNode(
      id: t.id,
      name: t.name,
      type: ConceptType.topic,
      related: [...relatedTopics, ...subIds],
      followUps: subIds,
    );
    for (final subId in subIds) {
      nodes[subId] = ConceptNode(
        id: subId,
        name: subId.split(':').last,
        type: ConceptType.subtopic,
        prerequisites: [t.id],
        related: [t.id],
      );
    }
  }
  return KnowledgeGraph(nodes);
}
