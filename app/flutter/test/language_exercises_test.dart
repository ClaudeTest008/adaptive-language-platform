import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/exercises.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/presentation/language_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';

Curriculum _load() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final curriculum = _load();
  final graph = curriculum.graph;

  group('exercise generation', () {
    test('derives all five text-first types from curriculum data', () {
      final items = generateExercises(graph, limit: 50);
      final types = items.map((e) => e.type).toSet();
      expect(
        types,
        containsAll([
          ExerciseType.multipleChoice,
          ExerciseType.fillInBlank,
          ExerciseType.translation,
          ExerciseType.sentenceBuilding,
          ExerciseType.readingComprehension,
        ]),
      );
      // Every item exercises a real graph node with a usable answer.
      for (final e in items) {
        expect(graph[e.node.conceptId], isNotNull);
        expect(e.answer, isNotEmpty);
      }
    });

    test('deterministic: same graph, same session', () {
      final a = generateExercises(graph, limit: 20);
      final b = generateExercises(graph, limit: 20);
      expect([for (final e in a) e.id], [for (final e in b) e.id]);
      expect([for (final e in a) e.options], [for (final e in b) e.options]);
    });

    test('sessions interleave exercise types instead of clustering', () {
      final items = generateExercises(graph, limit: 8);
      final firstFour = items.take(4).map((e) => e.type).toSet();
      expect(firstFour.length, greaterThanOrEqualTo(3));
    });

    test('focus concepts sort first (repair-driven sessions)', () {
      final items = generateExercises(
        graph,
        focusConceptIds: [tenerId],
        limit: 50,
      );
      final focused = items
          .takeWhile((e) => e.node.lineageConceptIds.contains(tenerId))
          .length;
      expect(focused, greaterThan(0));
      // No focused item appears after an unfocused one.
      final firstUnfocused = items.indexWhere(
        (e) => !e.node.lineageConceptIds.contains(tenerId),
      );
      expect(
        items
            .skip(firstUnfocused)
            .any((e) => e.node.lineageConceptIds.contains(tenerId)),
        isFalse,
      );
    });

    test('choice exercises always contain their answer', () {
      for (final e in generateExercises(graph, limit: 50)) {
        if (e.type == ExerciseType.multipleChoice ||
            e.type == ExerciseType.readingComprehension) {
          expect(e.options, contains(e.answer));
          expect(e.options.toSet().length, e.options.length);
        }
        if (e.type == ExerciseType.sentenceBuilding) {
          // Word bank is exactly the sentence's words.
          expect(e.options..sort(), e.answer.split(' ')..sort());
        }
      }
    });

    test('empty graph yields no exercises without crashing', () {
      expect(
        generateExercises(LanguageKnowledgeGraph(const [], const [])),
        isEmpty,
      );
    });

    test('English-for-Spanish curriculum generates exercises too', () {
      final en = parseCurriculum(
        jsonDecode(
              File('assets/curriculum/en-for-es.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final items = generateExercises(en.graph, limit: 20);
      expect(items, isNotEmpty);
      // Translation prompts name the right target language.
      final tr = items.where((e) => e.type == ExerciseType.translation);
      expect(tr.every((e) => e.prompt.contains('English')), isTrue);
    });

    test('checkAnswer normalizes case/spacing/punctuation, keeps accents', () {
      final item = generateExercises(graph, limit: 50)
          .firstWhere((e) => e.type == ExerciseType.translation);
      expect(checkAnswer(item, item.answer.toUpperCase()), isTrue);
      expect(checkAnswer(item, '  ${item.answer}.  '), isTrue);
      expect(checkAnswer(item, 'nonsense'), isFalse);
      // Diacritics matter: "esta" is not "está".
      const sentence = ExerciseItem(
        id: 'x',
        type: ExerciseType.fillInBlank,
        node: LanguageNode(
          tier: LanguageTier.exampleSentence,
          slug: 'x',
          name: 'x',
        ),
        prompt: 'p',
        answer: 'está',
      );
      expect(checkAnswer(sentence, 'esta'), isFalse);
      expect(checkAnswer(sentence, 'está'), isTrue);
    });
  });

  group('practice session controller', () {
    Future<ProviderContainer> makeContainer() async {
      final container = ProviderContainer(
        overrides: [
          curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
        ],
      );
      addTearDown(container.dispose);
      // Let the learner controller finish _init + demo seed.
      container.read(languageLearnerProvider);
      while (!container.read(languageLearnerProvider).ready) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    test('wrong answer on child exercise implicates ancestor concept', () async {
      final container = await makeContainer();
      final practice = container.read(languagePracticeProvider.notifier);
      practice.start(focusConceptIds: [tenerId], limit: 8);

      var s = container.read(languagePracticeProvider)!;
      expect(s.items, isNotEmpty);
      expect(s.current.node.lineageConceptIds, contains(tenerId));

      final before = container
          .read(languageLearnerProvider)
          .misconceptions
          .forConcept(tenerId)
          .fold(0, (sum, m) => sum + m.occurrences);

      await practice.submit('definitely wrong answer');
      s = container.read(languagePracticeProvider)!;
      expect(s.wasCorrect, isFalse);
      // Teacher feedback carries the tener misconception even though the
      // exercised node is a child phrase/sentence.
      expect(s.feedback.any((m) => m.conceptId == tenerId), isTrue);

      final learner = container.read(languageLearnerProvider);
      final after = learner.misconceptions
          .forConcept(tenerId)
          .fold(0, (sum, m) => sum + m.occurrences);
      expect(after, greaterThan(before));
      // Transfer signal registered on the ancestor concept.
      expect(learner.signals[tenerId].grammarTransferErrors, greaterThan(0));
      // Learning DNA derived live by the core engine.
      expect(learner.traits, isNotEmpty);
    });

    test('full session: submit/next through finish, score counted', () async {
      final container = await makeContainer();
      final practice = container.read(languagePracticeProvider.notifier);
      practice.start(limit: 4);

      var s = container.read(languagePracticeProvider)!;
      final total = s.items.length;
      final answeredBefore =
          container.read(languageLearnerProvider).model.totalAnswered;

      for (var i = 0; i < total; i++) {
        s = container.read(languagePracticeProvider)!;
        await practice.submit(s.current.answer); // always correct
        expect(container.read(languagePracticeProvider)!.wasCorrect, isTrue);
        expect(container.read(languagePracticeProvider)!.feedback, isEmpty);
        practice.next();
      }
      s = container.read(languagePracticeProvider)!;
      expect(s.finished, isTrue);
      expect(s.correctCount, total);
      // Every exercise produced a real answer event in the core model.
      expect(
        container.read(languageLearnerProvider).model.totalAnswered,
        answeredBefore + total,
      );
    });
  });
}
