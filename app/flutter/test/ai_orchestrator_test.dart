import 'package:adaptive_exam_platform/ai/chat_model.dart';
import 'package:adaptive_exam_platform/ai/orchestrator.dart';
import 'package:adaptive_exam_platform/domain/models.dart';
import 'package:adaptive_exam_platform/infrastructure/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiConversation', () {
    test('keeps system message and trims to maxTurns', () {
      final convo = AiConversation(system: 'sys', maxTurns: 2);
      convo.addUser('one');
      convo.addAssistant('two');
      convo.addUser('three');
      final messages = convo.messages;
      expect(messages.first.role, AiRole.system);
      expect(messages.length, 3); // system + last 2 turns
      expect(messages[1].content, 'two');
      expect(messages[2].content, 'three');
    });
  });

  group('AiOrchestrator over FakeChatModel', () {
    test('explainMistake grounds prompt in question data', () async {
      final model = FakeChatModel(handler: (_) => 'Because stop signs.');
      final tutor = AiOrchestrator(model);
      final answer = await tutor.explainMistake(
        question: demoQuestions.first,
        selectedIndex: 0,
      );
      expect(answer, 'Because stop signs.');
      final prompt = model.calls.single.last.content;
      expect(prompt, contains(demoQuestions.first.text));
      expect(prompt, contains(demoQuestions.first.explanation));
    });

    test(
      'generateQuestions returns DRAFTS attributed to the provider',
      () async {
        final model = FakeChatModel(
          handler: (_) =>
              '[{"question":"Q1?","answers":["a","b","c","d"],'
              '"correctIndex":1,"explanation":"E1"}]',
        );
        final generated = await AiOrchestrator(model).generateQuestions(
          topic: demoTopics.first,
          count: 1,
          difficulty: Difficulty.hard,
        );
        final q = generated.single;
        expect(q.status, ContentStatus.draft); // approval gate
        expect(q.author, 'ai:fake');
        expect(q.correctIndex, 1);
        expect(q.difficulty, Difficulty.hard);
        expect(q.topicId, demoTopics.first.id);
      },
    );

    test('generateQuestions rejects non-array output', () async {
      final model = FakeChatModel(handler: (_) => '{"oops": true}');
      expect(
        () => AiOrchestrator(model).generateQuestions(
          topic: demoTopics.first,
          count: 1,
          difficulty: Difficulty.easy,
        ),
        throwsFormatException,
      );
    });

    test('suggestMetadata parses classification JSON', () async {
      final model = FakeChatModel(
        handler: (_) =>
            '{"topicId":"signs","difficulty":"easy",'
            '"tags":["shapes"],"learningObjective":"Identify sign shapes"}',
      );
      final meta = await AiOrchestrator(
        model,
      ).suggestMetadata(demoQuestions.first, demoTopics.toList());
      expect(meta.topicId, 'signs');
      expect(meta.difficulty, Difficulty.easy);
      expect(meta.tags, ['shapes']);
      expect(meta.learningObjective, 'Identify sign shapes');
    });

    test('review clamps quality score and parses lists', () async {
      final model = FakeChatModel(
        handler: (_) =>
            '{"qualityScore":1.7,"issues":["ambiguous"],'
            '"suggestions":["reword"]}',
      );
      final review = await AiOrchestrator(model).review(demoQuestions.first);
      expect(review.qualityScore, 1.0); // clamped
      expect(review.issues, ['ambiguous']);
      expect(review.suggestions, ['reword']);
    });

    test('services registry exposes every implemented capability', () {
      final services = AiOrchestrator.services(FakeChatModel());
      expect(services.tutor, isNotNull);
      expect(services.coach, isNotNull);
      expect(services.explanationGenerator, isNotNull);
      expect(services.questionGenerator, isNotNull);
      expect(services.metadataGenerator, isNotNull);
      expect(services.contentReviewer, isNotNull);
      expect(services.documentExtractor, isNotNull);
      // Not orchestrated yet (needs binary transport):
      expect(services.ocr, isNull);
    });
  });
}
