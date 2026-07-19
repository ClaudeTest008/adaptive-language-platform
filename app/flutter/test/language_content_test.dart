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

    test('graded library covers a1-b1 with usable vocab + valid quizzes', () {
      final stories = parseStories(_storiesJson());
      // Progressive difficulty: every CEFR band the reader offers is stocked.
      for (final level in [CefrLevel.a1, CefrLevel.a2, CefrLevel.b1]) {
        expect(stories.where((s) => s.level == level), isNotEmpty);
      }
      for (final s in stories) {
        for (final v in s.vocabulary) {
          expect(v.word, isNotEmpty);
          expect(v.meaning, isNotEmpty);
        }
        for (final q in s.questions) {
          expect(q.prompt, isNotEmpty);
          expect(q.options.length, greaterThanOrEqualTo(2));
          expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1));
        }
      }
      // Everyday-situation pieces, dialogues and cultural articles all carry
      // key words and a comprehension check (the reader supports both).
      for (final id in [
        'es-a1-medico',
        'es-a1-estacion',
        'es-a1-reencuentro',
        'es-a2-primer-dia',
        'es-a2-piso',
        'es-a1-dialogo-panaderia',
        'es-a1-dialogo-taxi',
        'es-a2-dialogo-farmacia',
        'es-a2-horarios',
        'es-b1-siesta',
        'es-b1-lenguas',
      ]) {
        final s = stories.firstWhere((s) => s.id == id);
        expect(s.author, isNotEmpty, reason: id);
        expect(s.vocabulary, isNotEmpty, reason: id);
        expect(s.questions, isNotEmpty, reason: id);
      }
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

    test('session mixes drill kinds beyond repeat-after-me', () async {
      final speech = NoopSpeechService();
      final container = await makeContainer(speech);
      final ctrl = container.read(speakingProvider.notifier);
      ctrl.start(limit: 8);
      final kinds =
          container.read(speakingProvider)!.drills.map((d) => d.kind).toSet();
      expect(kinds.length, greaterThan(1));
      expect(kinds, contains(SpeakingDrillKind.spontaneous));
      expect(kinds, contains(SpeakingDrillKind.roleplay));
    });

    test('a session never repeats a target, and the next session moves on',
        () async {
      final speech = NoopSpeechService()..scriptedTranscript = 'algo';
      final container = await makeContainer(speech);
      final ctrl = container.read(speakingProvider.notifier);

      ctrl.start(limit: 5);
      final first = container.read(speakingProvider)!.drills
          .map((d) => d.target)
          .toList();
      expect(first.toSet(), hasLength(first.length)); // no in-session repeat

      // Practise every drill of the first session.
      for (var i = 0; i < first.length; i++) {
        await ctrl.attempt();
        ctrl.next();
      }
      ctrl.reset();

      ctrl.start(limit: 5);
      final second = container.read(speakingProvider)!.drills
          .map((d) => d.target)
          .toList();
      expect(second.toSet().intersection(first.toSet()), isEmpty);
    });

    test('spontaneous drills are attempted but never scored', () async {
      final speech = NoopSpeechService()
        ..scriptedTranscript = 'Me llamo Ana y soy de Madrid.';
      final container = await makeContainer(speech);
      final ctrl = container.read(speakingProvider.notifier);
      ctrl.start(limit: 40);

      // Walk to the first spontaneous drill.
      var s = container.read(speakingProvider)!;
      while (s.current.kind != SpeakingDrillKind.spontaneous) {
        ctrl.next();
        s = container.read(speakingProvider)!;
      }
      await ctrl.attempt();

      s = container.read(speakingProvider)!;
      expect(s.attempted, isTrue); // the learner did speak
      expect(s.score, isNull); // …and no number was invented
      expect(s.words, isEmpty);
      expect(s.instruction, 'Answer in your own words');
      // No fabricated pronunciation evidence reached the learner model.
      expect(container.read(speakingSessionsProvider), isEmpty);
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
