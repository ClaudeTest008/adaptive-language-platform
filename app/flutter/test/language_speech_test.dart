import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/lesson.dart';
import 'package:adaptive_exam_platform/language/misconceptions.dart';
import 'package:adaptive_exam_platform/language/signals.dart';
import 'package:adaptive_exam_platform/language/speaking.dart';
import 'package:adaptive_exam_platform/language/speech.dart';
import 'package:adaptive_exam_platform/language/exercises.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';
const manzanaId = 'es:a1:vocabulary:food:fruit:manzana';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final curriculum = _curriculum();
  final graph = curriculum.graph;

  group('spokenText (TTS normalization)', () {
    test('strips markdown emphasis so the engine never voices asterisks', () {
      expect(spokenText('Let\'s work on **tener for physical states**.'),
          "Let's work on tener for physical states.");
      expect(spokenText('English produces *soy cansado*.'),
          'English produces soy cansado.');
      expect(spokenText('Use the `tener` pattern.'), 'Use the tener pattern.');
    });

    test('keeps Spanish sentence punctuation for prosody', () {
      const q = '¿Cómo estás? ¡Bien!';
      expect(spokenText(q), q);
    });

    test('dialogue dashes and ellipses become natural pauses', () {
      expect(spokenText('—Quiero pan —dice Ana.'), 'Quiero pan, dice Ana.');
      expect(spokenText('Espera... ya voy.'), 'Espera. ya voy.');
    });

    test('drops list/heading markers and link URLs, collapses blank lines',
        () {
      expect(spokenText('# Title\n\n- one\n- two'), 'Title. one two');
      expect(spokenText('See [the docs](https://x.y) now.'),
          'See the docs now.');
    });
  });

  group('pronunciation scorer (phoneme-aware)', () {
    test('exact match is perfect with all words ok', () {
      final r = scorePronunciationDetailed('tener hambre', 'tener hambre');
      expect(r.score, 1.0);
      expect(r.words.every((w) => w.ok), isTrue);
      expect(r.words.map((w) => w.target), ['tener', 'hambre']);
    });

    test('near miss gets partial credit, not zero', () {
      // One vowel off (hambre vs hombre) — close but not identical.
      final r = scorePronunciationDetailed('hambre', 'hombre');
      expect(r.score, greaterThan(0.6));
      expect(r.score, lessThan(1.0));
      // Silent h is forgiven entirely (phonetic fold).
      expect(scorePronunciation('hambre', 'ambre'), 1.0);
    });

    test('per-word feedback flags the wrong word', () {
      final r = scorePronunciationDetailed('tener mucha hambre', 'tener hambre');
      final byWord = {for (final w in r.words) w.target: w};
      expect(byWord['tener']!.ok, isTrue);
      expect(byWord['hambre']!.ok, isTrue);
      expect(byWord['mucha']!.ok, isFalse); // not said → not ok
      expect(byWord['mucha']!.heard, isNull);
    });

    test('phonetic folding: b/v and accents count as matches', () {
      expect(scorePronunciation('vaca', 'baca'), 1.0);
      expect(scorePronunciation('está', 'esta'), 1.0);
      expect(scorePronunciation('tener', 'perro'), lessThan(0.4));
    });

    test('empty transcript scores zero with all words missed', () {
      final r = scorePronunciationDetailed('tener hambre', '');
      expect(r.score, 0);
      expect(r.words.every((w) => !w.ok && w.heard == null), isTrue);
      // Empty target is a degenerate zero, not a crash.
      expect(scorePronunciationDetailed('', 'algo').score, 0);
    });

    test('extra recognized words do not hurt the matched targets', () {
      final r = scorePronunciationDetailed('hambre', 'yo tengo hambre');
      expect(r.score, 1.0);
      expect(r.words.single.heard, 'hambre');
    });
  });

  group('listening exercises + signal', () {
    test('generator emits listening items with hidden audio', () {
      final items = generateExercises(graph, limit: 60);
      final listening =
          items.where((e) => e.type == ExerciseType.listening).toList();
      expect(listening, isNotEmpty);
      final one = listening.first;
      expect(one.audio, isNotEmpty);
      expect(one.options, contains(one.answer));
      // The prompt never leaks the target word.
      expect(one.prompt.contains(one.answer), isFalse);
    });

    test('afterListening seeds then EWMAs listeningRecognition', () {
      var s = const LanguageConceptSignals();
      expect(s.listeningRecognition, isNull);
      s = s.afterListening(true);
      expect(s.listeningRecognition, 1.0);
      final before = s.listeningRecognition!;
      s = s.afterListening(false);
      expect(s.listeningRecognition, lessThan(before));
      expect(s.usageFrequency, 2);
    });

    test('store records listening on concept lineage', () {
      final store = const LanguageSignalsStore()
          .afterListening(conceptIds: const [manzanaId], correct: true);
      expect(store[manzanaId].listeningRecognition, 1.0);
    });
  });

  group('lesson engine weighting by speech signals', () {
    final mastery = {tenerId: 0.2, manzanaId: 0.4};

    List<LessonBlock> plan(LanguageSignalsStore signals) => buildDailyLesson(
      conceptMastery: mastery,
      graph: graph,
      misconceptions: const MisconceptionLog(),
      signals: signals,
      availableMinutes: 40,
    );

    test('low pronunciation confidence gives more speaking minutes', () {
      final weak = const LanguageSignalsStore()
          .afterPronunciation(conceptIds: [tenerId, manzanaId], score: 0.1);
      final strong = const LanguageSignalsStore()
          .afterPronunciation(conceptIds: [tenerId, manzanaId], score: 0.95);
      int speakMin(List<LessonBlock> p) => p
          .where((b) => b.activity == LessonActivity.speaking)
          .fold(0, (s, b) => s + b.minutes);
      expect(speakMin(plan(weak)), greaterThan(speakMin(plan(strong))));
    });

    test('low conversation ability gives more conversation minutes', () {
      final weak = const LanguageSignalsStore().afterConversationTurn(
        conceptIds: [tenerId, manzanaId],
        quality: 0.1,
      );
      final strong = const LanguageSignalsStore().afterConversationTurn(
        conceptIds: [tenerId, manzanaId],
        quality: 0.95,
      );
      int convMin(List<LessonBlock> p) => p
          .where((b) => b.kind == LessonBlockKind.conversation)
          .fold(0, (s, b) => s + b.minutes);
      expect(convMin(plan(weak)), greaterThan(convMin(plan(strong))));
    });
  });
}
