/// Portable content pack (exam + topics + questions) JSON codec.
/// Format version 1 — see docs/product/07-content-studio-requirements.md.
library;

import 'dart:convert';

import '../domain/models.dart';

class ContentPack {
  const ContentPack({
    required this.exam,
    required this.topics,
    required this.questions,
  });

  final Exam exam;
  final List<Topic> topics;
  final List<Question> questions;
}

Map<String, dynamic> questionToJson(Question q) => {
  'id': q.id,
  'examId': q.examId,
  'topicId': q.topicId,
  'text': q.text,
  'answers': q.answers,
  'correctIndex': q.correctIndex,
  'explanation': q.explanation,
  'difficulty': q.difficulty.name,
  'status': q.status.name,
  'version': q.version,
  'tags': q.tags,
  if (q.subtopic != null) 'subtopic': q.subtopic,
  if (q.learningObjective != null) 'learningObjective': q.learningObjective,
  'references': q.references,
  if (q.author != null) 'author': q.author,
  if (q.updatedAt != null) 'updatedAt': q.updatedAt!.toIso8601String(),
};

Question questionFromJson(Map<String, dynamic> j) => Question(
  id: j['id'] as String,
  examId: j['examId'] as String,
  topicId: j['topicId'] as String,
  text: j['text'] as String,
  answers: (j['answers'] as List).cast<String>(),
  correctIndex: j['correctIndex'] as int,
  explanation: j['explanation'] as String,
  difficulty:
      Difficulty.values.asNameMap()[j['difficulty']] ?? Difficulty.medium,
  status:
      ContentStatus.values.asNameMap()[j['status']] ?? ContentStatus.published,
  version: (j['version'] as int?) ?? 1,
  tags: ((j['tags'] as List?) ?? const []).cast<String>(),
  subtopic: j['subtopic'] as String?,
  learningObjective: j['learningObjective'] as String?,
  references: ((j['references'] as List?) ?? const []).cast<String>(),
  author: j['author'] as String?,
  updatedAt: j['updatedAt'] != null
      ? DateTime.tryParse(j['updatedAt'] as String)
      : null,
);

String encodeContentPack({
  required Exam exam,
  required List<Topic> topics,
  required List<Question> questions,
}) => const JsonEncoder.withIndent('  ').convert({
  'format': 'adaptive-exam-content-pack',
  'formatVersion': 1,
  'exam': {
    'id': exam.id,
    'name': exam.name,
    'questionCount': exam.questionCount,
    'passThreshold': exam.passThreshold,
    'timeLimitMinutes': exam.timeLimitMinutes,
  },
  'topics': [
    for (final t in topics) {'id': t.id, 'name': t.name, 'order': t.order},
  ],
  'questions': [for (final q in questions) questionToJson(q)],
});

ContentPack decodeContentPack(String json) {
  final root = jsonDecode(json);
  if (root is! Map<String, dynamic> ||
      root['format'] != 'adaptive-exam-content-pack') {
    throw const FormatException('Not an adaptive-exam content pack.');
  }
  final e = root['exam'] as Map<String, dynamic>;
  return ContentPack(
    exam: Exam(
      id: e['id'] as String,
      name: e['name'] as String,
      questionCount: e['questionCount'] as int,
      passThreshold: e['passThreshold'] as int,
      timeLimitMinutes: e['timeLimitMinutes'] as int,
    ),
    topics: [
      for (final t in (root['topics'] as List).cast<Map<String, dynamic>>())
        Topic(
          id: t['id'] as String,
          name: t['name'] as String,
          order: t['order'] as int,
        ),
    ],
    questions: [
      for (final q in (root['questions'] as List).cast<Map<String, dynamic>>())
        questionFromJson(q),
    ],
  );
}
