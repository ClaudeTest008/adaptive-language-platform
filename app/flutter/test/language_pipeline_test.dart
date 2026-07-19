import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/infrastructure/demo_tutor_model.dart';
import 'package:adaptive_language_platform/ai/chat_model.dart';
import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/pipeline.dart';
import 'package:adaptive_language_platform/language/reasoning_engine.dart';
import 'package:adaptive_language_platform/language/relationships.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('language pipeline — the strict voice rule', () {
    test('English support never reaches the Spanish voice', () {
      const reply = '¡Hola! ¿Tú tienes hambre hoy? '
          'This means: are you hungry today? '
          'Piensa en «tener hambre».';
      final safe = speechSafeText(reply, 'es', 'en');
      expect(safe, contains('hambre'));
      expect(safe.toLowerCase(), isNot(contains('this means')));
      expect(safe.toLowerCase(), isNot(contains('are you hungry')));
    });

    test('fully English text produces empty speech for Spanish voice', () {
      const reply = 'You have improved your listening this week.';
      expect(speechSafeText(reply, 'es', 'en'), isEmpty);
    });

    test('splitTeacherReply separates target body from native support', () {
      const reply = '¿Qué te gusta comer? '
          'Grammar note: gustar works backwards — the thing pleases you.';
      final parts = splitTeacherReply(reply, 'es', 'en');
      expect(parts.target, contains('comer'));
      expect(parts.support, contains('Grammar note'));
    });
  });

  group('input sanitization', () {
    test('strips the \\|Si dictation artifact', () {
      expect(sanitizeUserInput(r'\|Si'), 'Si');
    });

    test('strips control characters and collapses whitespace', () {
      expect(sanitizeUserInput('  hola \x01  qué  tal '), 'hola qué tal');
    });

    test('keeps normal Spanish intact', () {
      expect(sanitizeUserInput('¡Tengo hambre!'), '¡Tengo hambre!');
    });
  });

  group('conversation variety — duplicate replies fixed', () {
    test('immersion never repeats the same question on consecutive turns',
        () async {
      final model = DemoTutorModel();
      final system = AiMessage(
        AiRole.system,
        'MODE: immersion\nTarget language: Spanish (es)\n',
      );
      final replies = <String>[];
      var history = <AiMessage>[system, AiMessage(AiRole.user, 'Start')];
      for (var turn = 0; turn < 4; turn++) {
        final r = await model.complete(history);
        replies.add(r);
        history = [
          ...history,
          AiMessage(AiRole.assistant, r),
          AiMessage(AiRole.user, 'Calor número $turn'),
        ];
      }
      for (var i = 1; i < replies.length; i++) {
        expect(replies[i], isNot(equals(replies[i - 1])),
            reason: 'turn $i repeated the previous reply');
      }
    });
  });

  group('teacher personality + adaptive feedback (from real brain)', () {
    final brain = const OfflineReasoningEngine().assemble(
      BrainInputs(
        today: DateTime(2026, 7, 18),
        nativeLanguage: 'en',
        targetLanguage: 'es',
        targetLanguageName: 'Spanish',
        baseLevel: 'A1',
        longTermGoal: 'Reach A2 Spanish',
        skillMastery: const {
          LanguageSkill.vocabulary: 0.5,
          LanguageSkill.grammar: 0.4,
        },
        conceptMastery: const {'es:a1:grammar:tener:hambre': 0.9},
        conceptNames: const {'es:a1:grammar:tener:hambre': 'tener hambre'},
        misconceptions: const [],
        accuracy: 0.6,
        totalAnswered: 30,
        learningDna: const [],
        historyDays: const [],
        vocabularyPoolSize: 100,
        relations: const [
          LanguageRelation(
            from: 'es:a1:grammar:tener:hambre',
            to: 'es:a1:grammar:tener:sueno',
            type: LanguageRelationType.relatedTo,
          ),
        ],
      ),
    );

    test('greeting comes from the notebook, not a canned phrase', () {
      final g = teacherGreeting(brain);
      expect(g, isNotNull);
      expect(
        brain.notebook.observations.map((o) => o.text).toList() +
            brain.curiosities.map((c) => c.text).toList(),
        contains(g),
      );
    });

    test('adaptive feedback references what the brain knows', () {
      final high = adaptiveFeedback(0.9, brain);
      expect(high, contains('automatic'));
      final low = adaptiveFeedback(0.3, brain);
      expect(low, isNotEmpty);
    });
  });

  group('reader explainWord — connections first, dictionary second', () {
    test('explains a known-adjacent word through connections', () {
      final curriculum = parseCurriculum(
        jsonDecode(
              File('assets/curriculum/es-for-en.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      // Build a brain over the real curriculum with one strong concept.
      final vocabIds = curriculum.graph.nodes.values
          .whereType<VocabularyConceptNode>()
          .toList();
      expect(vocabIds, isNotEmpty);
      final known = vocabIds.first;
      final brain = const OfflineReasoningEngine().assemble(
        BrainInputs(
          today: DateTime(2026, 7, 18),
          nativeLanguage: 'en',
          targetLanguage: 'es',
          targetLanguageName: 'Spanish',
          baseLevel: 'A1',
          longTermGoal: 'Reach A2 Spanish',
          skillMastery: const {LanguageSkill.vocabulary: 0.5},
          conceptMastery: {known.conceptId: 0.9},
          conceptNames: {
            for (final e in curriculum.graph.nodes.entries) e.key: e.value.name,
          },
          misconceptions: const [],
          accuracy: 0.6,
          totalAnswered: 30,
          learningDna: const [],
          historyDays: const [],
          vocabularyPoolSize: 100,
          relations: curriculum.graph.relations,
        ),
      );
      final e = explainWord(known.lemma, brain, curriculum);
      expect(e.conceptId, known.conceptId);
      // Dictionary present but the type keeps it secondary.
      expect(e.translation, isNotNull);
    });

    test('unknown word is honest — empty, not invented', () {
      final curriculum = parseCurriculum(
        jsonDecode(
              File('assets/curriculum/es-for-en.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final brain = const OfflineReasoningEngine().assemble(
        BrainInputs(
          today: DateTime(2026, 7, 18),
          nativeLanguage: 'en',
          targetLanguage: 'es',
          targetLanguageName: 'Spanish',
          baseLevel: 'A1',
          longTermGoal: 'Reach A2 Spanish',
          skillMastery: const {},
          conceptMastery: const {},
          conceptNames: const {},
          misconceptions: const [],
          accuracy: 0,
          totalAnswered: 0,
          learningDna: const [],
          historyDays: const [],
          vocabularyPoolSize: 100,
        ),
      );
      final e = explainWord('zzzznoexiste', brain, curriculum);
      expect(e.isEmpty, isTrue);
    });
  });
}
