import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/ai/chat_model.dart';
import 'package:adaptive_language_platform/infrastructure/demo_tutor_model.dart';
import 'package:adaptive_language_platform/language/conversation.dart';
import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/misconceptions.dart';
import 'package:adaptive_language_platform/language/signals.dart';
import 'package:adaptive_language_platform/language/tutor.dart';
import 'package:flutter_test/flutter_test.dart';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

const orderingId = 'es:a1:conversation:ordering-food';
const tenerId = 'es:a1:grammar:verbs:states:tener-states';

void main() {
  final curriculum = _curriculum();
  final graph = curriculum.graph;

  TutorContext conversationContext() => buildTutorContext(
    curriculum: curriculum,
    conceptMastery: {
      tenerId: 0.2,
      'es:a1:vocabulary:food:restaurant': 0.3,
    },
    misconceptions: const MisconceptionLog(),
    signals: const LanguageSignalsStore(),
    scenarioConceptId: orderingId,
  );

  group('scenario selection', () {
    test('prefers a scenario fed by a weak concept', () {
      final id = pickScenarioConceptId(
        graph,
        weakConceptIds: {'es:a1:vocabulary:food:restaurant'},
      );
      expect(id, orderingId); // restaurant feeds ordering-food
    });

    test('falls back to the first scenario when nothing is weak', () {
      final id = pickScenarioConceptId(graph);
      expect(id, isNotNull);
      expect(graph[id!], isNotNull);
    });
  });

  group('tutor context carries scenario + target vocabulary', () {
    test('scenario text and weak-concept vocab are assembled', () {
      final ctx = conversationContext();
      expect(ctx.scenarioConceptId, orderingId);
      expect(ctx.scenario, isNotNull);
      expect(ctx.scenario, contains('café'));
      // Vocab drawn from the weak tener family (phrases).
      expect(
        ctx.targetVocab.any((v) => v.contains('tener') || v.contains('hambre')),
        isTrue,
      );
    });

    test('prompt emits scenario + target vocabulary for the demo model', () {
      final p = tutorSystemPrompt(TutorMode.conversation, conversationContext());
      expect(p, contains('MODE: conversation'));
      expect(p, contains('Scenario:'));
      expect(p, contains('Target vocabulary to weave in:'));
      expect(p, contains('REACT'));
    });
  });

  group('conversation turn quality', () {
    test('longer replies and target-vocab use score higher', () {
      final vocab = ['tener hambre', 'manzana'];
      final short = conversationTurnQuality('Sí', vocab);
      final full =
          conversationTurnQuality('Sí, yo tengo mucha hambre hoy', vocab);
      expect(full, greaterThan(short));
      // Using a target phrase adds credit (accent-folded).
      final withVocab =
          conversationTurnQuality('quiero una manzana por favor', vocab);
      final without =
          conversationTurnQuality('quiero una cosa por favor', vocab);
      expect(withVocab, greaterThan(without));
      expect(conversationTurnQuality('', vocab), 0);
    });
  });

  group('conversationAbility signal', () {
    test('afterConversationTurn seeds then EWMAs', () {
      var s = const LanguageConceptSignals();
      expect(s.conversationAbility, isNull);
      s = s.afterConversationTurn(0.8);
      expect(s.conversationAbility, 0.8);
      expect(s.usageFrequency, 1);
      final before = s.conversationAbility!;
      s = s.afterConversationTurn(0.2);
      expect(s.conversationAbility, lessThan(before));
    });

    test('store records on the given concept ids', () {
      final store = const LanguageSignalsStore()
          .afterConversationTurn(conceptIds: const [orderingId], quality: 0.7);
      expect(store[orderingId].conversationAbility, 0.7);
    });
  });

  group('demo conversation is contextual and multi-turn', () {
    final tutor = LanguageTutor(const DemoTutorModel());

    test('opening greets and sets the scene with a question', () async {
      final reply = await tutor.respond(
        mode: TutorMode.conversation,
        context: conversationContext(),
        userMessage: 'Start the session.',
      );
      expect(reply.valid, isTrue);
      expect(reply.text, contains('?'));
      expect(reply.text.toLowerCase(), contains('hola'));
    });

    test('later turn reacts to the learner and asks a follow-up', () async {
      final reply = await tutor.respond(
        mode: TutorMode.conversation,
        context: conversationContext(),
        userMessage: 'Yo soy cansado',
        history: const [
          AiMessage(AiRole.assistant, '¡Hola! ¿Tú tienes hambre?'),
          AiMessage(AiRole.user, 'Sí'),
        ],
      );
      expect(reply.valid, isTrue);
      // Gently recasts the "soy cansado" error, then moves on with a question.
      expect(reply.text.toLowerCase(), contains('tengo sueño'));
      expect(reply.text, contains('?'));
    });

    test('immersion stays in the target language and progresses', () async {
      final reply = await tutor.respond(
        mode: TutorMode.immersion,
        context: conversationContext(),
        userMessage: 'Sí, gracias',
        history: const [
          AiMessage(AiRole.assistant, '¡Hola! ¿Tú tienes hambre?'),
          AiMessage(AiRole.user, 'Sí'),
        ],
      );
      expect(reply.valid, isTrue); // passes the native-language purity gate
      expect(reply.text, contains('¿'));
    });
  });
}
