import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/infrastructure/prefs_experience_repository.dart';
import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/experience.dart';
import 'package:adaptive_exam_platform/language/story.dart';
import 'package:adaptive_exam_platform/language/notebook_repository.dart';
import 'package:adaptive_exam_platform/language/teacher_memory.dart';
import 'package:adaptive_exam_platform/presentation/language_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  group('vocabulary mining', () {
    test('ranks recurring words and marks known vs unknown from real data',
        () {
      final curriculum = _curriculum();
      final vocab = curriculum.graph.nodes.values
          .whereType<VocabularyConceptNode>()
          .first;
      final text = '${vocab.lemma} ${vocab.lemma} ${vocab.lemma} '
          'castillo castillo misterioso';
      final mined = mineVocabulary(text, curriculum, {vocab.conceptId: 0.9});
      expect(mined.first.word, _foldEq(vocab.lemma));
      expect(mined.first.known, isTrue);
      final castillo = mined.firstWhere((m) => m.word == 'castillo');
      expect(castillo.known, isFalse);
      expect(castillo.count, 2);
    });

    test('empty text mines nothing', () {
      expect(mineVocabulary('', _curriculum(), const {}), isEmpty);
    });
  });

  group('reading records → outcomes + interests', () {
    Story story() => const Story(
      id: 's1',
      title: 'Viaje a Madrid',
      level: CefrLevel.a1,
      topics: ['travel', 'city'],
      phrases: [StoryPhrase(text: 'Vamos a Madrid.', translation: '')],
    );

    test('record measures known ratio from mined words', () {
      final record = buildReadingRecord(
        story: story(),
        mined: const [
          MinedWord(word: 'vamos', count: 1, known: true),
          MinedWord(word: 'madrid', count: 1, known: false),
        ],
        day: '2026-07-18',
      );
      expect(record.knownRatio, 0.5);
      expect(record.unknownWords, ['madrid']);
      expect(record.topics, ['travel', 'city']);
    });

    test('outcomes derive from records — measured, not invented', () {
      final outcomes = outcomesFromRecords([
        buildReadingRecord(
          story: story(),
          mined: const [MinedWord(word: 'vamos', count: 1, known: true)],
          day: '2026-07-18',
        ),
      ]);
      expect(outcomes.single.objective, contains('Viaje a Madrid'));
      expect(outcomes.single.score, 1.0);
    });

    test('interests discovered from completed-book topics, weighted', () {
      final records = [
        for (var i = 0; i < 3; i++)
          ReadingRecord(
            day: '2026-07-1$i',
            storyId: 's$i',
            title: 't$i',
            topics: const ['travel'],
            knownRatio: 0.5,
            unknownWords: const [],
          ),
        const ReadingRecord(
          day: '2026-07-18',
          storyId: 'sx',
          title: 'tx',
          topics: ['cooking'],
          knownRatio: 0.5,
          unknownWords: [],
        ),
      ];
      final interests = discoverInterests(records);
      expect(interests.first.topic, 'travel');
      expect(interests.first.weight, 1.0);
      expect(
        interests.firstWhere((i) => i.topic == 'cooking').weight,
        lessThan(1.0),
      );
    });

    test('no reading, no interests — nothing fabricated', () {
      expect(discoverInterests(const []), isEmpty);
    });
  });

  group('plain-text import', () {
    test('paragraphs become pages, long ones split at sentences', () {
      final long = List.filled(30, 'Una frase corta que sigue y sigue.').join(' ');
      final story = importPlainText(
        id: 'imp-1',
        title: 'Mi libro',
        text: 'Primer párrafo corto.\n\n$long',
      );
      expect(story.phrases.length, greaterThan(2));
      expect(story.phrases.first.text, 'Primer párrafo corto.');
      for (final p in story.phrases) {
        expect(p.text.length, lessThanOrEqualTo(460));
      }
    });

    test('ReadingRecord JSON round-trips', () {
      const r = ReadingRecord(
        day: '2026-07-18',
        storyId: 's1',
        title: 'T',
        topics: ['travel'],
        knownRatio: 0.75,
        unknownWords: ['faro'],
      );
      final back = ReadingRecord.fromJson(r.toJson());
      expect(back.knownRatio, 0.75);
      expect(back.topics, ['travel']);
      expect(back.unknownWords, ['faro']);
    });
  });

  test('prefs experience repository round-trips records, books, words',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrefsExperienceRepository();
    await repo.addReadingRecord(const ReadingRecord(
      day: '2026-07-18',
      storyId: 's1',
      title: 'T',
      topics: ['travel'],
      knownRatio: 0.6,
      unknownWords: [],
    ));
    await repo.saveImportedBook('b1', 'Mi libro', 'Hola mundo.');
    await repo.saveWord('faro');

    final fresh = PrefsExperienceRepository(); // simulated restart
    expect((await fresh.loadReadingRecords()).single.storyId, 's1');
    expect((await fresh.loadImportedBooks())['b1']!.title, 'Mi libro');
    expect(await fresh.loadSavedWords(), contains('faro'));
  });

  test('reading record session measurements round-trip and default to null',
      () {
    // Measured session (Phase 35/38 instrumentation).
    const measured = ReadingRecord(
      day: '2026-07-19',
      storyId: 's1',
      title: 'T',
      topics: [],
      knownRatio: 0.5,
      unknownWords: [],
      durationMs: 120000,
      pauseCount: 2,
      replays: 1,
      pagesRevisited: 3,
      wordTaps: 4,
    );
    final back = ReadingRecord.fromJson(
      jsonDecode(jsonEncode(measured.toJson())) as Map<String, dynamic>,
    );
    expect(back.durationMs, 120000);
    expect(back.pauseCount, 2);
    expect(back.replays, 1);
    expect(back.pagesRevisited, 3);
    expect(back.wordTaps, 4);

    // Legacy record json (no measurement keys) → nulls, never fabricated.
    final legacy = ReadingRecord.fromJson(const {
      'day': '2026-07-18',
      'storyId': 's0',
      'title': 'Old',
      'topics': <String>[],
      'knownRatio': 0.4,
      'unknownWords': <String>[],
    });
    expect(legacy.durationMs, isNull);
    expect(legacy.pauseCount, isNull);
    expect(legacy.replays, isNull);
    expect(legacy.pagesRevisited, isNull);
    expect(legacy.wordTaps, isNull);
  });

  test('buildReadingRecord carries measurements only when provided', () {
    const story = Story(
      id: 's2',
      title: 'Faro',
      level: CefrLevel.a1,
      phrases: [StoryPhrase(text: 'El faro brilla.', translation: '')],
    );
    final measured = buildReadingRecord(
      story: story,
      mined: const [],
      day: '2026-07-19',
      durationMs: 60000,
      wordTaps: 2,
    );
    expect(measured.durationMs, 60000);
    expect(measured.wordTaps, 2);
    expect(measured.pauseCount, isNull); // not measured → null

    final bare =
        buildReadingRecord(story: story, mined: const [], day: '2026-07-19');
    expect(bare.durationMs, isNull);
  });

  test('readingAnalyticsProvider feeds measured sessions into the report',
      () async {
    final repo = InMemoryExperienceRepository();
    await repo.addReadingRecord(const ReadingRecord(
      day: '2026-07-19',
      storyId: 's1',
      title: 'T',
      topics: [],
      knownRatio: 0.6,
      unknownWords: ['faro'],
      durationMs: 90000,
      pauseCount: 1,
      replays: 2,
      wordTaps: 3,
      wordsRead: 150,
    ));
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repo),
      teacherNotebookRepositoryProvider
          .overrideWithValue(InMemoryTeacherNotebookRepository()),
      teacherMemoryRepositoryProvider
          .overrideWithValue(InMemoryTeacherMemoryRepository()),
    ]);
    addTearDown(container.dispose);

    final report =
        await container.read(readingAnalyticsProvider.future);
    // Duration/pause/replay analytics are REAL now (previously structurally
    // null because the provider never passed sessions).
    expect(report.meanDurationMs, 90000);
    expect(report.replayCount, 2);
    expect(report.pauseFrequency, 1.0); // 1 pause / 1 measured session
    expect(report.wordsPerMinute, 100.0); // 150 words / 1.5 min — real WPM
  });
}

Matcher _foldEq(String lemma) => predicate<String>(
  (w) =>
      w ==
      lemma
          .toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('ü', 'u')
          .replaceAll(RegExp(r'[^a-zñáéíóúü]'), '') ||
      w == lemma.toLowerCase(),
  'matches folded lemma',
);
