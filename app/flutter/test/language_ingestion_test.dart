import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/ingestion.dart';
import 'package:flutter_test/flutter_test.dart';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

const _passage =
    'María tiene mucha hambre. Va a un pequeño restaurante en Sevilla. '
    'El camarero habla español despacio. María quiere comer una manzana '
    'roja. También tiene sed. En España la comida es a las tres.';

void main() {
  final curriculum = _curriculum();
  final graph = curriculum.graph;

  IngestionResult ingest([String text = _passage]) =>
      ingestLanguageText(text, graph: graph, languageCode: 'es');

  group('content extraction', () {
    test('produces candidates across kinds', () {
      final r = ingest();
      expect(r.candidates, isNotEmpty);
      expect(r.ofKind(ContentKind.vocabulary), isNotEmpty);
      expect(r.ofKind(ContentKind.sentence), isNotEmpty);
      expect(r.ofKind(ContentKind.idiom), isNotEmpty); // "tener hambre"
    });

    test('recognized vocabulary maps to a curriculum concept', () {
      final r = ingest();
      final manzana = r
          .ofKind(ContentKind.vocabulary)
          .where((c) => c.text == 'manzana')
          .toList();
      expect(manzana, isNotEmpty);
      expect(manzana.first.conceptId, 'es:a1:vocabulary:food:fruit:manzana');
      expect(manzana.first.mapped, isTrue);
    });

    test('unknown words are flagged new, not mapped', () {
      final r = ingest();
      final novel = r
          .ofKind(ContentKind.vocabulary)
          .where((c) => c.text == 'restaurante' || c.text == 'camarero');
      expect(novel, isNotEmpty);
      expect(novel.every((c) => !c.mapped), isTrue);
      expect(novel.every((c) => c.note == 'new word'), isTrue);
    });

    test('idioms carry a gloss and map when in the phrase family', () {
      final r = ingest();
      final tener = r
          .ofKind(ContentKind.idiom)
          .firstWhere((c) => c.text == 'tener hambre');
      expect(tener.translation, 'to be hungry');
      // "tener hambre" is a phrase node in the curriculum.
      expect(tener.mapped, isTrue);
    });

    test('cultural note flagged from a keyword (España/Sevilla)', () {
      final r = ingest();
      expect(r.ofKind(ContentKind.culturalNote), isNotEmpty);
    });

    test('difficulty + topics are derived', () {
      final r = ingest();
      expect(CefrLevel.values, contains(r.difficulty));
      expect(r.topics, isNotEmpty);
    });

    test('empty text yields no candidates without crashing', () {
      final r = ingest('   ');
      expect(r.candidates, isEmpty);
      expect(r.difficulty, CefrLevel.a1);
    });

    test('extraction is deterministic', () {
      final a = ingest();
      final b = ingest();
      expect(a.candidates.map((c) => c.id), b.candidates.map((c) => c.id));
    });
  });

  group('review queue', () {
    test('approve / reject move a candidate out of pending', () {
      var log = const ContentReviewLog();
      expect(log.isPending('vocabulary:manzana'), isTrue);
      log = log.approve('vocabulary:manzana');
      expect(log.isPending('vocabulary:manzana'), isFalse);
      expect(log.approved, contains('vocabulary:manzana'));
      // Rejecting later flips it.
      log = log.reject('vocabulary:manzana');
      expect(log.approved, isNot(contains('vocabulary:manzana')));
      expect(log.rejected, contains('vocabulary:manzana'));
    });
  });
}
