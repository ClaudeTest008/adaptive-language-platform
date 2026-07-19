import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/signals.dart';
import 'package:adaptive_language_platform/language/speaking.dart';
import 'package:adaptive_language_platform/language/speech.dart';
import 'package:adaptive_language_platform/language/story.dart';
import 'package:adaptive_language_platform/presentation/language_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

Map<String, dynamic> _storiesJson() =>
    jsonDecode(File('assets/stories/es-for-en.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final curriculum = _curriculum();

  group('stories', () {
    test('seed stories parse with phrases, translations, concept ids', () {
      final stories = parseStories(_storiesJson());
      expect(stories, isNotEmpty);
      final restaurant = stories.firstWhere((s) => s.id == 'es-a1-restaurante');
      expect(restaurant.level, CefrLevel.a1);
      expect(restaurant.phrases.first.text, contains('María tiene mucha hambre'));
      expect(restaurant.phrases.first.translation, isNotEmpty);
      expect(restaurant.phrases.first.conceptIds, contains(tenerId));
      // fullText joins every phrase for whole-story listening.
      expect(restaurant.fullText, contains('María tiene mucha hambre'));
      expect(restaurant.fullText, contains('contenta'));
      // Concept coverage feeds recommendation.
      expect(restaurant.conceptIds, contains(tenerId));
    });

    test('classic stories carry vocabulary + comprehension questions', () {
      final stories = parseStories(_storiesJson());
      final quijote =
          stories.firstWhere((s) => s.id == 'es-b1-quijote-molinos');
      expect(quijote.level, CefrLevel.b1);
      expect(quijote.vocabulary, isNotEmpty);
      expect(quijote.vocabulary.first.word, isNotEmpty);
      expect(quijote.vocabulary.first.meaning, isNotEmpty);
      expect(quijote.questions, hasLength(3));
      final q = quijote.questions.first;
      expect(q.options.length, greaterThanOrEqualTo(2));
      expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1));
      // Legacy stories still parse with empty vocab/questions.
      final mercado = stories.firstWhere((s) => s.id == 'es-a1-mercado');
      expect(mercado.questions, isEmpty);
    });

    test('flagship novel parses with chapters and real length', () {
      final novel = parseStories(
        jsonDecode(
              File('assets/stories/es-novela-faro.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      ).single;
      expect(novel.id, 'es-a2-novela-faro');
      expect(novel.hasChapters, isTrue);
      expect(novel.chapterTitles, hasLength(7));
      expect(novel.chapterStarts.first, 0);
      // Continuous pages across chapters; a real book, not an exercise.
      expect(novel.phrases.length, greaterThanOrEqualTo(40));
      expect(novel.readingMinutes, greaterThanOrEqualTo(15));
      // chapterOf maps pages to chapters monotonically.
      expect(novel.chapterOf(0), 0);
      expect(novel.chapterOf(novel.phrases.length - 1), 6);
      // Quiz exists but is optional (never forced by the reader).
      expect(novel.questions, isNotEmpty);
    });

    test('recommendedLevel drops a level only when struggling', () {
      expect(recommendedLevel(CefrLevel.a2, averageMastery: 0.8), CefrLevel.a2);
      expect(recommendedLevel(CefrLevel.a2, averageMastery: 0.2), CefrLevel.a1);
      // A1 never drops below itself.
      expect(recommendedLevel(CefrLevel.a1, averageMastery: 0.0), CefrLevel.a1);
    });

    test('storiesForLevel includes at-or-below, easiest first', () {
      final stories = [
        const Story(id: 'x', title: 'B1', level: CefrLevel.b1, phrases: []),
        const Story(id: 'y', title: 'A1', level: CefrLevel.a1, phrases: []),
        const Story(id: 'z', title: 'A2', level: CefrLevel.a2, phrases: []),
      ];
      final atA2 = storiesForLevel(stories, CefrLevel.a2);
      expect(atA2.map((s) => s.level), [CefrLevel.a1, CefrLevel.a2]);
    });
  });

  group('speaking drills', () {
    test('generates speakable targets, focus concepts first', () {
      final drills = generateSpeakingDrills(
        curriculum.graph,
        focusConceptIds: [tenerId],
        limit: 20,
      );
      expect(drills, isNotEmpty);
      // First drill is on the focus concept's lineage.
      expect(drills.first.node.lineageConceptIds, contains(tenerId));
      // Every drill has a non-empty target.
      for (final d in drills) {
        expect(d.target, isNotEmpty);
      }
    });

    test('scorePronunciation: exact match perfect, accents folded', () {
      expect(scorePronunciation('tener hambre', 'tener hambre'), 1.0);
      // Recognizer drops the accent — still counts.
      expect(scorePronunciation('está', 'esta'), 1.0);
      // Half the words right.
      expect(scorePronunciation('tener hambre', 'tener'), closeTo(0.5, 1e-9));
      expect(scorePronunciation('tener hambre', 'nonsense words'), 0.0);
    });
  });

  group('pronunciation signal', () {
    test('afterPronunciation seeds then EWMAs confidence', () {
      var s = const LanguageConceptSignals();
      expect(s.pronunciationConfidence, isNull);
      s = s.afterPronunciation(0.8);
      expect(s.pronunciationConfidence, 0.8);
      expect(s.usageFrequency, 1);
      final before = s.pronunciationConfidence!;
      s = s.afterPronunciation(0.2);
      expect(s.pronunciationConfidence, lessThan(before));
    });

    test('store records on the given concepts', () {
      final store = const LanguageSignalsStore()
          .afterPronunciation(conceptIds: const [tenerId], score: 0.9);
      expect(store[tenerId].pronunciationConfidence, 0.9);
    });
  });

  group('speaking controller (with fake speech)', () {
    Future<ProviderContainer> makeContainer(NoopSpeechService speech) async {
      final container = ProviderContainer(
        overrides: [
          curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
          speechServiceProvider.overrideWithValue(speech),
        ],
      );
      addTearDown(container.dispose);
      container.read(languageLearnerProvider);
      while (!container.read(languageLearnerProvider).ready) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    test('attempt scores the utterance and records confidence', () async {
      final speech = NoopSpeechService();
      final container = await makeContainer(speech);
      final ctrl = container.read(speakingProvider.notifier);
      ctrl.start(focusConceptIds: [tenerId], limit: 6);

      final target = container.read(speakingProvider)!.current.target;
      // Simulate the learner saying the target back perfectly.
      speech.scriptedTranscript = target;
      await ctrl.attempt();

      final s = container.read(speakingProvider)!;
      expect(s.transcript, target);
      expect(s.score, 1.0);
      // Confidence recorded on the drilled concept.
      final node = s.current.node;
      expect(
        container.read(languageLearnerProvider).signals[node.conceptId]
            .pronunciationConfidence,
        isNotNull,
      );
      expect(speech.spoken, isEmpty); // playTarget not called here
    });

    test('playTarget speaks the current target', () async {
      final speech = NoopSpeechService()..scriptedTranscript = 'x';
      final container = await makeContainer(speech);
      final ctrl = container.read(speakingProvider.notifier);
      ctrl.start(limit: 3);
      await ctrl.playTarget();
      expect(speech.spoken, hasLength(1));
    });

    test('null transcript (denied/unsupported) leaves the drill unattempted',
        () async {
      final speech = NoopSpeechService(); // scriptedTranscript null
      final container = await makeContainer(speech);
      final ctrl = container.read(speakingProvider.notifier);
      ctrl.start(limit: 3);
      await ctrl.attempt();
      expect(container.read(speakingProvider)!.attempted, isFalse);
    });
  });
}
