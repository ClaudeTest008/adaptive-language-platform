import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/ai/chat_model.dart';
import 'package:adaptive_language_platform/infrastructure/demo_tutor_model.dart';
import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/misconceptions.dart';
import 'package:adaptive_language_platform/language/signals.dart';
import 'package:adaptive_language_platform/language/tutor.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';

Curriculum _load() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final curriculum = _load();
  final at = DateTime(2026, 7, 16);

  MisconceptionLog logWithTener() {
    final detector = MisconceptionDetector(
      curriculum.graph,
      nativeLanguage: 'en',
    );
    var log = const MisconceptionLog();
    log = log.record(
      detector.detect(conceptIds: const [tenerId], correct: false, at: at),
    );
    log = log.record(
      detector.detect(conceptIds: const [tenerId], correct: false, at: at),
    );
    return log;
  }

  TutorContext context({String? focus}) => buildTutorContext(
    curriculum: curriculum,
    conceptMastery: {
      tenerId: 0.2,
      'es:a1:vocabulary:food:fruit:manzana': 0.9,
      'es:a1:grammar:verbs:present-tense:ar-verbs': 0.5,
    },
    misconceptions: logWithTener(),
    signals: const LanguageSignalsStore().afterAnswer(
      conceptIds: const [tenerId],
      correct: false,
      responseSeconds: 8,
      transferConceptIds: const {tenerId},
    ),
    goals: const ['Reach A2'],
    learningTraits: const ['benefitsFromRepetition'],
    focusConceptId: focus,
  );

  group('tutor context assembly', () {
    test('weak concepts sorted weakest-first, misconceptions included', () {
      final ctx = context();
      expect(ctx.weakConcepts.first.conceptId, tenerId);
      expect(ctx.weakConcepts.first.mastery, 0.2);
      expect(ctx.misconceptions, isNotEmpty);
      expect(ctx.misconceptions.first.occurrences, 2);
      expect(ctx.skillMastery[LanguageSkill.grammar], isNotNull);
      expect(ctx.signalsSummary[tenerId]!.grammarTransferErrors, 1);
      expect(ctx.nativeLanguage, 'en');
    });

    test('focus concept brings graph slice: relations + pattern family', () {
      final ctx = context(focus: tenerId);
      expect(ctx.focusConcept!.conceptId, tenerId);
      expect(ctx.focusRelations, isNotEmpty);
      expect(
        ctx.focusFamily.map((n) => n.name),
        contains('tener hambre'),
      );
    });
  });

  group('mode prompts', () {
    test('prompts carry MODE tag and per-mode dialogue plan', () {
      final ctx = context(focus: tenerId);
      final p = tutorSystemPrompt(TutorMode.socratic, ctx);
      expect(p, contains('MODE: socratic'));
      expect(p, contains('Session flow:'));
      expect(p, contains('NEVER state the rule'));
      expect(
        tutorSystemPrompt(TutorMode.teacher, ctx),
        contains('comprehension check question'),
      );
    });

    test('each mode has a distinct persona; context serialized once', () {
      final ctx = context(focus: tenerId);
      final prompts = {
        for (final m in TutorMode.values) m: tutorSystemPrompt(m, ctx),
      };
      expect(prompts.values.toSet(), hasLength(TutorMode.values.length));
      for (final p in prompts.values) {
        expect(p, contains('[LEARNER CONTEXT]'));
        expect(p, contains('tener'));
        expect(p, contains('Native language: en'));
        expect(p, contains('Goals: Reach A2'));
        expect(p, contains('Learning style: benefitsFromRepetition'));
      }
      expect(
        prompts[TutorMode.immersion],
        contains('ONLY in the target language'),
      );
      expect(prompts[TutorMode.socratic], contains('Never state the answer'));
    });
  });

  group('output validation', () {
    final ctx = context(focus: tenerId);

    test('immersion purity: native language must not leak', () {
      // Native = English (es-for-en curriculum). English sentence → reject.
      expect(
        validateTutorReply(
          TutorMode.immersion,
          ctx,
          'You are doing great, keep practicing the phrases!',
        ),
        contains('native language leaked'),
      );
      // Pure Spanish passes.
      expect(
        validateTutorReply(
          TutorMode.immersion,
          ctx,
          '¡Hola! Yo tengo hambre. ¿Tú también?',
        ),
        isNull,
      );
      // Other modes are free to use the native language.
      expect(
        validateTutorReply(
          TutorMode.teacher,
          ctx,
          'The tener family covers physical states like tener hambre.',
        ),
        isNull,
      );
    });

    test('rejects empty, oversized and context-leaking replies', () {
      expect(validateTutorReply(TutorMode.teacher, ctx, '  '), isNotNull);
      expect(
        validateTutorReply(TutorMode.teacher, ctx, 'x' * 4001),
        isNotNull,
      );
      expect(
        validateTutorReply(
          TutorMode.teacher,
          ctx,
          'Here is my data: [LEARNER CONTEXT] tener…',
        ),
        isNotNull,
      );
    });

    test('teacher replies must ground in the focus concept', () {
      expect(
        validateTutorReply(
          TutorMode.teacher,
          ctx,
          'Today we discuss the weather in Madrid.',
        ),
        isNotNull,
      );
      expect(
        validateTutorReply(
          TutorMode.teacher,
          ctx,
          "Let's look at tener for physical states: tener hambre means…",
        ),
        isNull,
      );
      // Non-focused modes are not grounded-checked.
      expect(
        validateTutorReply(
          TutorMode.coach,
          ctx,
          'Great work today! Ten minutes tomorrow.',
        ),
        isNull,
      );
    });
  });

  group('LanguageTutor service', () {
    test('valid model output passes through', () async {
      final tutor = LanguageTutor(
        FakeChatModel(handler: (_) => 'tener hambre practice time.'),
      );
      final reply = await tutor.respond(
        mode: TutorMode.teacher,
        context: context(focus: tenerId),
        userMessage: 'Start the session.',
      );
      expect(reply.valid, isTrue);
      expect(reply.text, contains('tener'));
    });

    test('invalid output is replaced by safe fallback, never shown', () async {
      final tutor = LanguageTutor(FakeChatModel(handler: (_) => ''));
      final reply = await tutor.respond(
        mode: TutorMode.teacher,
        context: context(focus: tenerId),
        userMessage: 'Start the session.',
      );
      expect(reply.valid, isFalse);
      expect(reply.rejected, 'empty reply');
      expect(reply.text, contains('could not produce a valid reply'));
    });

    test('history flows to the model between turns', () async {
      final fake = FakeChatModel(handler: (_) => 'tener — sí, muy bien.');
      final tutor = LanguageTutor(fake);
      await tutor.respond(
        mode: TutorMode.teacher,
        context: context(focus: tenerId),
        userMessage: 'And tener miedo?',
        history: const [
          AiMessage(AiRole.assistant, 'We covered tener hambre.'),
          AiMessage(AiRole.user, 'Got it.'),
        ],
      );
      final sent = fake.calls.single;
      expect(sent, hasLength(4)); // system + 2 history + user
      expect(sent[1].content, contains('tener hambre'));
    });
  });

  group('demo tutor model (teacher mode live flow)', () {
    test('teaches the focus concept with misconception repair from real '
        'graph data', () async {
      final tutor = LanguageTutor(const DemoTutorModel());
      final reply = await tutor.respond(
        mode: TutorMode.teacher,
        context: context(focus: tenerId),
        userMessage: 'Start the session.',
      );
      expect(reply.valid, isTrue);
      expect(reply.text, contains('tener for physical states'));
      // Misconception repair speaks first-class.
      expect(reply.text, contains('tener'));
      expect(reply.text.toLowerCase(), contains('hambre'));
    });

    test('each mode composes a distinct, mode-true reply', () async {
      final tutor = LanguageTutor(const DemoTutorModel());
      Future<TutorReply> reply(TutorMode m) => tutor.respond(
        mode: m,
        context: context(focus: tenerId),
        userMessage: 'Start the session.',
      );

      final socratic = await reply(TutorMode.socratic);
      expect(socratic.valid, isTrue);
      expect(socratic.text, endsWith('?')); // asks, never tells

      final coach = await reply(TutorMode.coach);
      expect(coach.text, contains('plan for today'));
      expect(coach.text, contains('Reach A2')); // real goal from context

      final grammar = await reply(TutorMode.grammar);
      expect(grammar.text, contains('Pattern:'));
      expect(grammar.text, contains('Minimal pairs'));

      final conversation = await reply(TutorMode.conversation);
      expect(conversation.text, contains('?'));

      final immersion = await reply(TutorMode.immersion);
      expect(immersion.valid, isTrue); // passes the purity gate
      expect(immersion.text, contains('tengo'));
    });

    test('immersion follow-up turns stay pure', () async {
      final tutor = LanguageTutor(const DemoTutorModel());
      final second = await tutor.respond(
        mode: TutorMode.immersion,
        context: context(focus: tenerId),
        userMessage: 'Sí, yo también.',
        history: const [
          AiMessage(AiRole.assistant, '¡Hola! ¿Tú tienes hambre?'),
          AiMessage(AiRole.user, 'Sí.'),
        ],
      );
      expect(second.valid, isTrue);
      expect(second.text, contains('¿'));
    });

    test('without context it still replies validly', () async {
      final empty = buildTutorContext(
        curriculum: curriculum,
        conceptMastery: const {},
        misconceptions: const MisconceptionLog(),
        signals: const LanguageSignalsStore(),
      );
      final tutor = LanguageTutor(const DemoTutorModel());
      final reply = await tutor.respond(
        mode: TutorMode.conversation,
        context: empty,
        userMessage: 'Hola',
      );
      expect(reply.valid, isTrue);
      expect(reply.text, isNotEmpty);
    });
  });
}
