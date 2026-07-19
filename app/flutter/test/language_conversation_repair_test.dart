import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/infrastructure/gguf_teacher_voice.dart';
import 'package:adaptive_language_platform/infrastructure/prefs_experience_repository.dart';
import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/message_intent.dart';
import 'package:adaptive_language_platform/language/notebook_repository.dart';
import 'package:adaptive_language_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_language_platform/language/local_llm/llm_prompt_builder.dart';
import 'package:adaptive_language_platform/language/pipeline.dart';
import 'package:adaptive_language_platform/language/roleplay_engine.dart';
import 'package:adaptive_language_platform/language/teacher_intelligence.dart';
import 'package:adaptive_language_platform/language/speech.dart';
import 'package:adaptive_language_platform/language/teacher_memory.dart';
import 'package:adaptive_language_platform/language/tutor.dart';
import 'package:adaptive_language_platform/presentation/language_providers.dart';
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
          {'reason': 'my wife is Mexican', 'wife': 'Mexican'});
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
        'wife': 'Mexican',
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

    test('TTS gate: English never reaches the Spanish voice (clause-level)',
        () {
      // The exact line observed spoken on device before the fix.
      const leaked = 'Muy bien. Afinemos una cosa: One thing to tighten: '
          'Physical and emotional states. It follows the same pattern as '
          'Present tense, Verbs, Regular -ar verbs.';
      final spoken = speechSafeText(leaked, 'es', 'en');
      expect(spoken, contains('Muy bien'));
      expect(spoken, isNot(contains('tighten')));
      expect(spoken, isNot(contains('Physical')));
      expect(spoken, isNot(contains('Present tense')));
      // Bilingual fact answer: Spanish spoken, English only shown.
      final fact = speechSafeText(
          'Te llamas John. — Your name is John.', 'es', 'en');
      expect(fact, contains('Te llamas John'));
      expect(fact, isNot(contains('Your name')));
      // Learner-driven confusion moment: Spanish lead spoken, English support
      // dropped from speech (still on screen via splitTeacherReply.support).
      final confusion = speechSafeText(
          'Tranquilo, lo explico de otra manera con un ejemplo. '
          '— No problem: a simpler explanation, with a concrete example.',
          'es',
          'en');
      expect(confusion, contains('Tranquilo'));
      expect(confusion, isNot(contains('simpler')));
    });

    test('wife fact + pronominal reason compose deterministically', () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);
      await tutor.send('My wife is Mexican.');
      await tutor.send('I am learning Spanish because of her.');
      await tutor.send('Why am I learning Spanish?');
      final reply = c.read(tutorSessionProvider)!.transcript.last.$2;
      expect(reply, contains('esposa'));
      expect(reply, contains('wife'));
      expect(reply, contains('Mexican'));
    });

    test('speaking practice prefers fresh material after completion',
        () async {
      final c = ProviderContainer(overrides: [
        curriculumProvider.overrideWith((ref) => Future.value(parseCurriculum(
            jsonDecode(File('assets/curriculum/es-for-en.json')
                .readAsStringSync()) as Map<String, dynamic>))),
        speechServiceProvider
            .overrideWithValue(NoopSpeechService(scriptedTranscript: 'hola')),
        teacherNotebookRepositoryProvider
            .overrideWithValue(InMemoryTeacherNotebookRepository()),
        experienceRepositoryProvider
            .overrideWithValue(InMemoryExperienceRepository()),
        teacherMemoryRepositoryProvider
            .overrideWithValue(InMemoryTeacherMemoryRepository()),
      ]);
      addTearDown(c.dispose);
      await c.read(curriculumProvider.future);
      final speaking = c.read(speakingProvider.notifier);
      speaking.start();
      final firstTarget = c.read(speakingProvider)!.current.target;
      await speaking.attempt(); // scripted transcript scores the drill
      speaking.next(); // marks it completed
      speaking.reset();
      speaking.start();
      final nextTarget = c.read(speakingProvider)!.current.target;
      // The completed phrase never immediately leads the queue again.
      expect(nextTarget, isNot(equals(firstTarget)));
    });

    test('brain-driven teacher moments are Spanish, no node names', () async {
      final c = await _boot();
      final brain = c.read(teacherBrainProvider).value!;
      const engine = TeacherIntelligenceEngine();
      for (final intent in [
        TeacherIntent.greet,
        TeacherIntent.correct,
        TeacherIntent.encourage,
        TeacherIntent.review,
        TeacherIntent.practice,
        TeacherIntent.reflect,
      ]) {
        final m = engine.moment(
          brain,
          TeacherDecision(intent: intent, rationale: 'r'),
        );
        final low = m.message.toLowerCase();
        expect(low, isNot(contains('let me')));
        expect(low, isNot(contains('one thing to tighten')));
        expect(low, isNot(contains('physical and emotional')));
        expect(low, isNot(contains('present tense')));
        expect(m.message, isNotEmpty);
      }
      // The weak-grammar correction never dumps the internal concept label.
      final corr = engine.correction(brain);
      if (corr != null) {
        expect(corr.correction.toLowerCase(), isNot(contains('one thing')));
        expect(corr.praise, isNot(contains('came through clearly')));
      }
    });

    test('roleplay request classification + kind steering', () {
      expect(classifyLearnerMessage('You are a waiter.'),
          LearnerIntent.roleplayRequest);
      expect(roleplayKindFromRequest('You are a waiter.'),
          RoleplayKind.restaurant);
      expect(roleplayKindFromRequest("Let's practice ordering food."),
          RoleplayKind.restaurant);
      expect(roleplayKindFromRequest('Can we check into a hotel?'),
          RoleplayKind.hotel);
      expect(roleplayKindFromRequest('At the airport please'),
          RoleplayKind.airport);
      expect(roleplayKindFromRequest('I live in London.'), isNull);
    });

    test('explicit scene request builds that exact scenario', () async {
      final c = await _boot();
      final tutor = c.read(tutorSessionProvider.notifier);
      await tutor.start(TutorMode.teacher);
      await tutor.send('You are a waiter.');
      final s = c.read(tutorSessionProvider)!;
      expect(s.roleplay, isNotNull);
      expect(s.roleplay!.scenario.kind, RoleplayKind.restaurant);
    });

    test('English chat converses, never corrects; Spanish output is teachable',
        () async {
      final c = await _boot();
      final brain = c.read(teacherBrainProvider).value!;
      const eng = TeacherIntelligenceEngine();

      // An English life-statement mid-lesson → converse, no correction.
      final chat = eng.plan(brain,
          turn: 4,
          learnerIntent: LearnerIntent.statement,
          producedTarget: false);
      expect(chat.moment.converse, isTrue);
      expect(chat.correction, isNull);

      // An actual Spanish attempt → correction may fire.
      final spanish = eng.plan(brain,
          turn: 4,
          learnerIntent: LearnerIntent.statement,
          producedTarget: true);
      expect(spanish.moment.converse, isFalse);

      // The prompt for a converse turn instructs react-and-follow-up.
      final prompt = buildTeacherPrompt(
        brain: brain,
        plan: chat,
        context: const ConversationContext(),
        userMessage: 'My wife is Mexican.',
        supportMode: TeacherSupportMode.mentor,
      );
      expect(prompt.system, contains('CONVERSATION'));
      expect(prompt.system, isNot(contains('Correct exactly ONE')));
    });

    test('looksLikeSpanish only fires on real Spanish', () {
      expect(looksLikeSpanish('My wife is Mexican.'), isFalse);
      expect(looksLikeSpanish('I live in London.'), isFalse);
      expect(looksLikeSpanish('Tengo mucha hambre.'), isTrue);
      expect(looksLikeSpanish('Quiero un café, por favor.'), isTrue);
      expect(looksLikeSpanish('Hola'), isTrue);
    });

    test('reasoning think-blocks never reach the learner', () {
      expect(stripThink('<think>internal chain</think>¡Hola! ¿Qué tal?'),
          '¡Hola! ¿Qué tal?');
      expect(stripThink('<think></think>Claro.'), 'Claro.');
      // Unclosed block mid-stream → hidden entirely.
      expect(stripThink('<think>still reason'), isEmpty);
      expect(stripThink('Sin bloques.'), 'Sin bloques.');
    });

    test('corrections keep a cadence instead of firing every turn', () async {
      final c = await _boot();
      final brain = c.read(teacherBrainProvider).value!;
      const eng = TeacherIntelligenceEngine();

      TeacherResponsePlan planWith({
        required int since,
        String? lastConcept,
      }) =>
          eng.plan(
            brain,
            turn: 4,
            learnerIntent: LearnerIntent.statement,
            producedTarget: true,
            turnsSinceCorrection: since,
            lastCorrectedConceptId: lastConcept,
          );

      // A Spanish attempt with no recent correction → the teacher may correct.
      final fresh = planWith(since: ConversationContext.neverCorrected);
      expect(fresh.correction, isNotNull);
      final correctedId = fresh.correction!.conceptId;

      // Immediately afterwards it must NOT correct again — back-to-back
      // corrections are what made the tutor feel like a grammar checker.
      expect(planWith(since: 0, lastConcept: correctedId).correction, isNull);
      expect(planWith(since: 1, lastConcept: correctedId).correction, isNull);

      // The same point stays off-limits a little longer than the base gap.
      expect(planWith(since: 2, lastConcept: correctedId).correction, isNull);
      expect(planWith(since: 3, lastConcept: correctedId).correction, isNull);
      expect(planWith(since: 4, lastConcept: correctedId).correction, isNotNull);

      // A different point only waits out the base gap.
      expect(planWith(since: 2, lastConcept: 'other:concept').correction,
          isNotNull);
      c.dispose();
    });

    test('free-chat openers rotate instead of repeating one line', () async {
      final c = await _boot();
      final brain = c.read(teacherBrainProvider).value!;
      const eng = TeacherIntelligenceEngine();

      // Consecutive chat turns must not produce the same fallback opener —
      // a single fixed line made the offline tutor read as a chatbot.
      final lines = [
        for (var turn = 1; turn <= 6; turn++)
          eng
              .plan(brain,
                  turn: turn,
                  learnerIntent: LearnerIntent.statement,
                  producedTarget: false)
              .moment
              .message,
      ];
      expect(lines.toSet().length, greaterThan(3));
      for (var i = 1; i < lines.length; i++) {
        expect(lines[i], isNot(equals(lines[i - 1])));
      }
      // Still deterministic: the same turn always gives the same opener.
      expect(
        eng
            .plan(brain,
                turn: 2,
                learnerIntent: LearnerIntent.statement,
                producedTarget: false)
            .moment
            .message,
        lines[1],
      );
      c.dispose();
    });

    test('the correction clock only advances on learner turns', () {
      const start = ConversationContext();
      final afterTeacher = start
          .withCorrection('es:a1:grammar:tener')
          .withTurn(const ConversationTurn(fromLearner: false, text: 'Bien.'));
      expect(afterTeacher.turnsSinceCorrection, 0);
      expect(afterTeacher.lastCorrectedConceptId, 'es:a1:grammar:tener');

      final afterLearner = afterTeacher
          .withTurn(const ConversationTurn(fromLearner: true, text: 'Sí.'));
      expect(afterLearner.turnsSinceCorrection, 1);
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
