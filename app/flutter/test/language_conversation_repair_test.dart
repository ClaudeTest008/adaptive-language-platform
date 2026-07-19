import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/infrastructure/prefs_experience_repository.dart';
import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/message_intent.dart';
import 'package:adaptive_exam_platform/language/notebook_repository.dart';
import 'package:adaptive_exam_platform/language/speech.dart';
import 'package:adaptive_exam_platform/language/teacher_memory.dart';
import 'package:adaptive_exam_platform/language/tutor.dart';
import 'package:adaptive_exam_platform/presentation/language_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conversation-repair regression suite: the tutor must react to what the
/// learner actually says, remember explicitly-shared facts, keep history,
/// and stay deterministic.
Future<ProviderContainer> _boot() async {
  final c = ProviderContainer(overrides: [
    curriculumProvider.overrideWith((ref) => Future.value(parseCurriculum(
        jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
            as Map<String, dynamic>))),
    speechServiceProvider.overrideWithValue(NoopSpeechService()),
    teacherNotebookRepositoryProvider
        .overrideWithValue(InMemoryTeacherNotebookRepository()),
    experienceRepositoryProvider
        .overrideWithValue(InMemoryExperienceRepository()),
    teacherMemoryRepositoryProvider
        .overrideWithValue(InMemoryTeacherMemoryRepository()),
  ]);
  await c.read(curriculumProvider.future);
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (c.read(teacherBrainProvider).value != null) break;
  }
  return c;
}

void main() {
  group('deterministic message understanding', () {
    test('classifier covers the request taxonomy', () {
      expect(classifyLearnerMessage('Hello.'), LearnerIntent.greeting);
      expect(classifyLearnerMessage('goodbye!'), LearnerIntent.farewell);
      expect(
          classifyLearnerMessage("I don't understand."), LearnerIntent.confusion);
      expect(classifyLearnerMessage('Can you give me another example?'),
          LearnerIntent.exampleRequest);
      expect(classifyLearnerMessage('Can you explain ser vs estar?'),
          LearnerIntent.grammarRequest);
      // "in Spanish" wins as translation — same teaching moment either way.
      expect(classifyLearnerMessage('How do you say dog in Spanish?'),
          LearnerIntent.translationRequest);
      expect(classifyLearnerMessage('What does gato mean?'),
          LearnerIntent.vocabularyRequest);
      expect(classifyLearnerMessage('Can we practice ordering food?'),
          LearnerIntent.roleplayRequest);
      expect(classifyLearnerMessage('Quiz me please'),
          LearnerIntent.practiceRequest);
      expect(classifyLearnerMessage('My name is John.'),
          LearnerIntent.statement);
      expect(classifyLearnerMessage('Where do I live?'),
          LearnerIntent.question);
    });

    test('fact extraction is explicit-only, never inferred', () {
      expect(extractLearnerFacts('My name is John.'), {'name': 'John'});
      expect(extractLearnerFacts('I live in London.'), {'city': 'London'});
      expect(extractLearnerFacts('I have two children.'),
          {'children': 'two'});
      expect(extractLearnerFacts('I like football.'),
          {'interest': 'football'});
      expect(
          extractLearnerFacts(
              'I am learning Spanish because my wife is Mexican.'),
          {'reason': 'my wife is Mexican'});
      // Nothing stated → nothing stored.
      expect(extractLearnerFacts('The weather is nice.'), isEmpty);
    });

    test('answerFromFacts answers truthfully or admits ignorance', () {
      final facts = {'name': 'John', 'city': 'London', 'children': 'two'};
      expect(answerFromFacts('What is my name?', facts), contains('John'));
      expect(answerFromFacts('Where do I live?', facts), contains('London'));
      expect(answerFromFacts('How many children do I have?', facts),
          contains('two'));
      expect(answerFromFacts('What is my name?', const {}),
          contains("haven't told me"));
      expect(answerFromFacts('Explain the subjunctive.', facts), isNull);
    });
  });

  group('live tutor conversation', () {
    test('greeting stays a greeting — never opens with a correction',
        () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);
      final opener = c.read(tutorSessionProvider)!.transcript.last.$2;
      expect(opener.toLowerCase(), isNot(contains('ajuste')));
      expect(opener.toLowerCase(), isNot(contains('tighten')));

      await tutor.send('Hello.');
      final reply = c.read(tutorSessionProvider)!.transcript.last.$2;
      expect(reply, contains('Hola'));
    });

    test('remembers name, city and reason; answers questions about them',
        () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);

      await tutor.send('My name is John.');
      await tutor.send('I live in London.');
      await tutor.send('I have two children.');
      await tutor.send('I am learning Spanish because my wife is Mexican.');
      expect(c.read(learnerFactsProvider), {
        'name': 'John',
        'city': 'London',
        'children': 'two',
        'reason': 'my wife is Mexican',
      });

      Future<String> ask(String q) async {
        await tutor.send(q);
        return c.read(tutorSessionProvider)!.transcript.last.$2;
      }

      expect(await ask('What is my name?'), contains('John'));
      expect(await ask('Where do I live?'), contains('London'));
      expect(await ask('How many children do I have?'), contains('two'));
      expect(await ask('Why am I learning Spanish?'),
          contains('wife is Mexican'));
    });

    test('confusion changes the explanation; example request gives a new one',
        () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);

      await tutor.send('Can you explain ser vs estar?');
      final explain = c.read(tutorSessionProvider)!.transcript.last.$2;
      await tutor.send('I do not understand.');
      final reExplain = c.read(tutorSessionProvider)!.transcript.last.$2;
      await tutor.send('Can you give me another example?');
      final example = c.read(tutorSessionProvider)!.transcript.last.$2;

      expect(reExplain, isNot(equals(explain))); // changed the explanation
      expect(reExplain.toLowerCase(), contains('simpler'));
      expect(example, isNot(equals(reExplain))); // new example, new wording
      expect(example.toLowerCase(), contains('example'));
    });

    test('roleplay request starts a scene and keeps the conversation',
        () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);
      await tutor.send('Hello.');
      final before =
          c.read(tutorSessionProvider)!.transcript.length;

      await tutor.send('Can we practice ordering food?');
      final s = c.read(tutorSessionProvider)!;
      expect(s.roleplay, isNotNull); // scene actually started
      expect(s.transcript.length, greaterThan(before)); // history preserved
      expect(s.transcript.first.$1, isTrue); // original opener still there
    });

    test('conversation history reaches the model prompt', () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);
      await tutor.send('My name is John.');
      await tutor.send('I like football.');
      final s = c.read(tutorSessionProvider)!;
      // The stored conversation carries both learner turns…
      expect(
          s.conversation.turns.any((t) => t.text.contains('John')), isTrue);
      expect(s.conversation.turns.any((t) => t.text.contains('football')),
          isTrue);
      // …and the prompt builder now exposes them as chat history.
      // (LlmPrompt.history mapping is asserted in language_local_llm_test.)
    });

    test('the whole conversation is deterministic', () async {
      Future<List<String>> script() async {
        final c = await _boot();
        final tutor = c.read(tutorSessionProvider.notifier);
        await tutor.start(TutorMode.teacher);
        await tutor.send('Hello.');
        await tutor.send('My name is John.');
        await tutor.send('What is my name?');
        await tutor.send('Can you explain ser vs estar?');
        final out = [
          for (final (isTutor, text) in c.read(tutorSessionProvider)!.transcript)
            if (isTutor) text,
        ];
        c.dispose();
        return out;
      }

      expect(await script(), await script());
    });
  });
}
