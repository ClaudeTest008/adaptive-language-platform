import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/lesson.dart';
import 'package:adaptive_language_platform/language/misconceptions.dart';
import 'package:adaptive_language_platform/language/relationships.dart';
import 'package:adaptive_language_platform/language/signals.dart';
import 'package:adaptive_language_platform/language/story.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';
const manzanaId = 'es:a1:vocabulary:food:fruit:manzana';
const arVerbsId = 'es:a1:grammar:verbs:present-tense:ar-verbs';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

List<Story> _stories() => parseStories(
  jsonDecode(File('assets/stories/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

MisconceptionLog _tenerLog(LanguageKnowledgeGraph graph) {
  final d = MisconceptionDetector(graph, nativeLanguage: 'en');
  var log = const MisconceptionLog();
  log = log.record(d.detect(conceptIds: const [tenerId], correct: false, at: DateTime(2026)));
  log = log.record(d.detect(conceptIds: const [tenerId], correct: false, at: DateTime(2026)));
  return log;
}

void main() {
  final curriculum = _curriculum();
  final graph = curriculum.graph;
  final stories = _stories();

  final mastery = {
    tenerId: 0.2,
    arVerbsId: 0.55,
    manzanaId: 0.9,
    'es:a1:vocabulary:food:restaurant': 0.5,
  };

  group('daily lesson engine', () {
    test('repair leads, budget is respected, blocks carry reasons', () {
      final blocks = buildDailyLesson(
        conceptMastery: mastery,
        graph: graph,
        misconceptions: _tenerLog(graph),
        signals: const LanguageSignalsStore(),
        availableMinutes: 30,
      );
      expect(blocks, isNotEmpty);
      expect(blocks.first.kind, LessonBlockKind.repair);
      expect(blocks.first.conceptIds, contains(tenerId));
      expect(blocks.fold(0, (s, b) => s + b.minutes), 30);
      // Every block explains itself and gets a runnable activity.
      for (final b in blocks) {
        expect(b.reason, isNotEmpty);
        expect(b.minutes, greaterThanOrEqualTo(5));
      }
    });

    test('spaced-repetition due concepts produce a review block', () {
      final blocks = buildDailyLesson(
        conceptMastery: mastery,
        graph: graph,
        misconceptions: const MisconceptionLog(),
        signals: const LanguageSignalsStore(),
        dueConceptIds: {arVerbsId},
        availableMinutes: 30,
      );
      final review =
          blocks.where((b) => b.kind == LessonBlockKind.review).toList();
      expect(review, isNotEmpty);
      expect(review.first.conceptIds, contains(arVerbsId));
      expect(review.first.reason.toLowerCase(), contains('spaced'));
    });

    test('low pronunciation confidence adds a speaking block', () {
      final blocks = buildDailyLesson(
        conceptMastery: {tenerId: 0.3},
        graph: graph,
        misconceptions: const MisconceptionLog(),
        signals: const LanguageSignalsStore(),
        availableMinutes: 30,
      );
      final speak = blocks
          .where((b) => b.activity == LessonActivity.speaking)
          .toList();
      expect(speak, isNotEmpty);
      expect(speak.first.kind, LessonBlockKind.pronunciation);
    });

    test('a story block points at a real story via its id', () {
      final blocks = buildDailyLesson(
        conceptMastery: mastery,
        graph: graph,
        misconceptions: _tenerLog(graph),
        signals: const LanguageSignalsStore(),
        stories: stories,
        availableMinutes: 40,
      );
      final story =
          blocks.where((b) => b.activity == LessonActivity.story).toList();
      expect(story, isNotEmpty);
      expect(stories.any((s) => s.id == story.first.storyId), isTrue);
      // The chosen story overlaps today's focus concepts.
      final chosen = stories.firstWhere((s) => s.id == story.first.storyId);
      expect(chosen.conceptIds.contains(tenerId), isTrue);
    });

    test('Learning DNA shapes the plan: repeatsMistakes boosts repair', () {
      List<LessonBlock> plan(List<String> traits) => buildDailyLesson(
        conceptMastery: mastery,
        graph: graph,
        misconceptions: _tenerLog(graph),
        signals: const LanguageSignalsStore(),
        traits: traits,
        availableMinutes: 40,
      );
      final base = plan(const []);
      final boosted = plan(const ['repeatsMistakes']);
      expect(
        boosted.first.minutes,
        greaterThan(base.first.minutes),
      );
      expect(boosted.first.reason.toLowerCase(), contains('repeat'));
    });

    test('strugglesUnderTimePressure caps to fewer, longer blocks', () {
      final blocks = buildDailyLesson(
        conceptMastery: mastery,
        graph: graph,
        misconceptions: _tenerLog(graph),
        signals: const LanguageSignalsStore(),
        traits: const ['strugglesUnderTimePressure'],
        stories: stories,
        availableMinutes: 30,
      );
      expect(blocks.length, lessThanOrEqualTo(3));
      expect(blocks.fold(0, (s, b) => s + b.minutes), 30);
    });

    test('every block maps to a launchable activity', () {
      final blocks = buildDailyLesson(
        conceptMastery: mastery,
        graph: graph,
        misconceptions: _tenerLog(graph),
        signals: const LanguageSignalsStore(),
        stories: stories,
        availableMinutes: 45,
      );
      for (final b in blocks) {
        switch (b.activity) {
          case LessonActivity.story:
            expect(b.storyId, isNotNull);
          case LessonActivity.practice:
          case LessonActivity.speaking:
            expect(b.conceptIds, isNotEmpty);
          case LessonActivity.tutor:
            break; // tutor needs no payload
        }
      }
    });
  });

  group('enriched stories', () {
    test('phrases are multi-sentence narrative paragraphs with translations',
        () {
      for (final s in stories) {
        expect(s.phrases, isNotEmpty);
        for (final p in s.phrases) {
          expect(p.translation, isNotEmpty);
          // Each page is a real narrative paragraph, not a textbook line.
          expect(p.text.split(' ').length, greaterThanOrEqualTo(12));
        }
      }
    });
  });
}
