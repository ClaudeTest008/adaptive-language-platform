/// AI orchestrator (ADR-0010): implements the domain AI capability
/// interfaces on top of any [AiChatModel]. Business logic never sees a
/// vendor; swapping Anthropic/OpenAI/Gemini/local means binding a
/// different chat model in DI. All generated content is emitted as
/// DRAFTS — administrator approval gates publication, always.
library;

import 'dart:convert';

import '../domain/ai_services.dart';
import '../domain/models.dart';
import 'chat_model.dart';

class AiOrchestrator
    implements
        AiTutor,
        AiStudyCoach,
        AiExplanationGenerator,
        AiQuestionGenerator,
        AiMetadataGenerator,
        AiContentReviewer,
        AiDocumentExtractor {
  const AiOrchestrator(this.model);

  final AiChatModel model;

  @override
  bool get isAvailable => true;

  /// Builds the full [AiServices] registry backed by one chat model.
  static AiServices services(AiChatModel model) {
    final o = AiOrchestrator(model);
    return AiServices(
      tutor: o,
      coach: o,
      explanationGenerator: o,
      questionGenerator: o,
      metadataGenerator: o,
      contentReviewer: o,
      documentExtractor: o,
    );
  }

  Future<String> _ask(String system, String user) => model.complete([
    AiMessage(AiRole.system, system),
    AiMessage(AiRole.user, user),
  ]);

  // ------------------------------------------------------------- learner

  @override
  Future<String> explainMistake({
    required Question question,
    required int selectedIndex,
  }) => _ask(
    'You are a patient driving instructor. Explain mistakes briefly and '
        'concretely, grounded in the provided explanation. Never invent rules.',
    'Question: ${question.text}\n'
        'Student answered: ${question.answers[selectedIndex]}\n'
        'Correct answer: ${question.answers[question.correctIndex]}\n'
        'Reference explanation: ${question.explanation}\n'
        'Explain why the student answer is wrong and how to remember the rule.',
  );

  @override
  Future<String> coach({required String learnerSummary}) => _ask(
    'You are an encouraging study coach for exam preparation. Give short, '
    'specific, actionable advice based only on the provided statistics.',
    learnerSummary,
  );

  // ------------------------------------------------------------- content

  @override
  Future<String> generateExplanation(Question question) => _ask(
    'Write a concise factual explanation (2-3 sentences) for the correct '
        'answer of an exam question. No preamble.',
    'Question: ${question.text}\n'
        'Correct answer: ${question.answers[question.correctIndex]}',
  );

  @override
  Future<List<Question>> generateQuestions({
    required Topic topic,
    required int count,
    required Difficulty difficulty,
  }) async {
    final raw = await _ask(
      'Generate multiple-choice exam questions as a JSON array. Each item: '
          '{"question": string, "answers": [4 strings], "correctIndex": int, '
          '"explanation": string}. Output JSON only.',
      'Topic: ${topic.name}. Count: $count. Difficulty: ${difficulty.name}.',
    );
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      throw const FormatException('AI question output was not a JSON array.');
    }
    return [
      for (final (i, item) in parsed.cast<Map<String, dynamic>>().indexed)
        Question(
          id: 'ai-${topic.id}-${DateTime.now().microsecondsSinceEpoch}-$i',
          examId: '',
          topicId: topic.id,
          text: item['question'] as String,
          answers: (item['answers'] as List).cast<String>(),
          correctIndex: item['correctIndex'] as int,
          explanation: item['explanation'] as String,
          difficulty: difficulty,
          // Approval gate: AI output is ALWAYS a draft; it enters the
          // same import/review pipeline as any human-authored content.
          status: ContentStatus.draft,
          author: 'ai:${model.providerName}',
        ),
    ];
  }

  /// Extracts question candidates from document text (ADR-0011). Output
  /// rows use the import-pipeline column contract, so extracted content
  /// flows through the exact same validation + review + approval path as
  /// any bulk import — grounding excerpt included for side-by-side review.
  @override
  Future<List<Map<String, String>>> extractQuestions(
    String documentText,
  ) async {
    final raw = await _ask(
      'Extract multiple-choice exam questions strictly grounded in the '
      'provided source text — never invent facts absent from it. '
      'Respond with a JSON array. Each item: {"question": string, '
      '"answerA": string, "answerB": string, "answerC": string, '
      '"answerD": string, "correct": "A"|"B"|"C"|"D", '
      '"explanation": string, "sourceExcerpt": the exact source '
      'sentence the question is grounded in}. JSON only.',
      documentText,
    );
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      throw const FormatException('AI extraction output was not a JSON array.');
    }
    return [
      for (final item in parsed)
        if (item is Map)
          {
            for (final e in item.entries)
              e.key.toString(): e.value?.toString() ?? '',
          },
    ];
  }

  @override
  Future<AiSuggestedMetadata> suggestMetadata(
    Question question,
    List<Topic> topics,
  ) async {
    final raw = await _ask(
      'Classify an exam question. Respond with JSON only: '
          '{"topicId": one of the provided ids, "difficulty": '
          '"easy"|"medium"|"hard", "tags": [strings], '
          '"learningObjective": string}.',
      'Topics: ${topics.map((t) => '${t.id} (${t.name})').join(', ')}\n'
          'Question: ${question.text}\n'
          'Answers: ${question.answers.join(' | ')}',
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return AiSuggestedMetadata(
      topicId: parsed['topicId'] as String?,
      difficulty: Difficulty.values.asNameMap()[parsed['difficulty']],
      tags: ((parsed['tags'] as List?) ?? const []).cast<String>(),
      learningObjective: parsed['learningObjective'] as String?,
    );
  }

  @override
  Future<AiContentReview> review(Question question) async {
    final raw = await _ask(
      'Review an exam question for quality (clarity, single defensible '
          'correct answer, plausible distractors, explanation quality). '
          'Respond with JSON only: {"qualityScore": 0..1, "issues": [strings], '
          '"suggestions": [strings]}.',
      'Question: ${question.text}\n'
          'Answers: ${question.answers.join(' | ')}\n'
          'Correct: ${question.answers[question.correctIndex]}\n'
          'Explanation: ${question.explanation}',
    );
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return AiContentReview(
      qualityScore: (parsed['qualityScore'] as num).toDouble().clamp(0, 1),
      issues: ((parsed['issues'] as List?) ?? const []).cast<String>(),
      suggestions: ((parsed['suggestions'] as List?) ?? const [])
          .cast<String>(),
    );
  }
}
