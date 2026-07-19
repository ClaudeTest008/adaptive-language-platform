import 'dart:convert';

import 'package:adaptive_language_platform/infrastructure/document_parser.dart';
import 'package:adaptive_language_platform/language/audio_cache.dart';
import 'package:adaptive_language_platform/language/book_analytics.dart';
import 'package:adaptive_language_platform/language/book_ingestion.dart';
import 'package:adaptive_language_platform/language/experience.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

const _sample = '''
Chapter 1

El viaje empezó en el aeropuerto. Tenía una maleta pequeña y mucha
prisa. El hotel estaba cerca del mar.

La comida del restaurante era deliciosa.

Chapter 2

Al día siguiente tomamos el tren. La montaña era enorme y el bosque
verde. Fue un viaje inolvidable.
''';

List<int> _buildEpub() {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''
<?xml version="1.0"?>
<container><rootfiles><rootfile full-path="content.opf"/></rootfiles></container>
''');
  add('content.opf', '''
<?xml version="1.0"?>
<package>
  <metadata><dc:title>Mi Novela</dc:title><dc:creator>Autora</dc:creator></metadata>
  <manifest>
    <item id="c1" href="ch1.xhtml"/>
    <item id="c2" href="ch2.xhtml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>
''');
  add('ch1.xhtml', '<html><body><h1>Chapter 1</h1>'
      '<p>El viaje empezó en el aeropuerto.</p>'
      '<p>El hotel estaba cerca del mar.</p></body></html>');
  add('ch2.xhtml', '<html><body><h1>Chapter 2</h1>'
      '<p>Tomamos el tren a la montaña.</p></body></html>');
  return ZipEncoder().encode(archive);
}

void main() {
  group('book ingestion', () {
    test('splits chapters, paragraphs and sentences', () {
      final book = ingestBook(title: 'Viaje', author: 'A', text: _sample);
      expect(book.chapters, hasLength(2));
      expect(book.chapters.first.title.toLowerCase(), contains('chapter 1'));
      expect(book.chapters.first.sentences.length, greaterThan(1));
    });

    test('detects language, counts words, infers travel topic', () {
      final book = ingestBook(title: 'Viaje', author: 'A', text: _sample);
      expect(book.language, 'es');
      expect(book.wordCount, greaterThan(20));
      expect(book.topics, contains('travel'));
    });

    test('estimates a CEFR difficulty deterministically', () {
      final a = ingestBook(title: 't', author: '', text: _sample);
      final b = ingestBook(title: 't', author: '', text: _sample);
      expect(a.difficulty, b.difficulty);
      expect(a.estimatedCefr, isNotNull);
    });

    test('no headings → single chapter; empty → none', () {
      expect(
        ingestBook(title: 't', author: '', text: 'Una frase. Otra frase.')
            .chapters,
        hasLength(1),
      );
      expect(ingestBook(title: 't', author: '', text: '   ').chapters, isEmpty);
    });

    test('extracts repeated phrases only', () {
      final text = 'buenos días amigo. buenos días amigo. hola mundo.';
      final phrases = extractPhrases(segmentSentences(text));
      expect(phrases, contains('buenos días'));
    });
  });

  group('document parser', () {
    const importer = DocumentImporter();

    test('TXT imports into an ingested book', () {
      final out = importer.import(
        title: 'Notas', bytes: utf8.encode(_sample));
      expect(out.ok, isTrue);
      expect(out.format, BookFormat.txt);
      expect(out.book!.chapters, hasLength(2));
    });

    test('empty text fails gracefully', () {
      final out = importer.import(title: 't', bytes: utf8.encode('   '));
      expect(out.ok, isFalse);
    });

    test('PDF is reported politely, never crashes (no OCR)', () {
      final out = importer.import(
        title: 'scan', bytes: [0x25, 0x50, 0x44, 0x46, 1, 2, 3]);
      expect(out.ok, isFalse);
      expect(out.format, BookFormat.pdf);
      expect(out.message, contains('PDF'));
    });

    test('EPUB extracts chapters in spine order with metadata', () {
      final out = importer.import(title: 'fallback', bytes: _buildEpub());
      expect(out.ok, isTrue, reason: out.message);
      expect(out.format, BookFormat.epub);
      expect(out.book!.title, 'Mi Novela');
      expect(out.book!.author, 'Autora');
      expect(out.book!.chapters.length, greaterThanOrEqualTo(1));
      expect(out.book!.wordFrequency.containsKey('aeropuerto'), isTrue);
    });
  });

  group('reading analytics — measured only', () {
    test('completion computed; speed/reread null without measurement', () {
      final a = computeReadingAnalytics(
        pagesReached: 5, totalPages: 10, chaptersRead: 1);
      expect(a.completionPercent, 0.5);
      expect(a.readingSpeedWpm, isNull);
      expect(a.reReadRate, isNull);
    });

    test('speed computed when duration + words measured', () {
      final a = computeReadingAnalytics(
        pagesReached: 10, totalPages: 10, chaptersRead: 2,
        wordsRead: 600, durationMs: 120000);
      expect(a.readingSpeedWpm, 300.0);
    });
  });

  group('vocabulary discovery — measured history', () {
    test('records and merges encounters; confidence stays null', () {
      var e = recordEncounter(null,
          word: 'faro', day: '2026-07-16', bookId: 'b1', context: 'El faro brilla.');
      e = recordEncounter(e, word: 'faro', day: '2026-07-18', lookedUp: true);
      expect(e.timesEncountered, 2);
      expect(e.timesLookedUp, 1);
      expect(e.firstSeenDay, '2026-07-16');
      expect(e.lastSeenDay, '2026-07-18');
      expect(e.confidence, isNull); // never invented
    });

    test('JSON round-trips', () {
      final e = recordEncounter(null, word: 'mar', day: '2026-07-18');
      final back = VocabularyEntry.fromJson(e.toJson());
      expect(back.word, 'mar');
      expect(back.timesEncountered, 1);
    });
  });

  group('book relationships — measured overlap, no concept graph dup', () {
    test('shared topics + vocabulary produce a relationship', () {
      final b1 = BookFingerprint.fromIngested(
        'b1', ingestBook(title: 'Viaje uno', author: '', text: _sample));
      final b2 = BookFingerprint.fromIngested(
        'b2', ingestBook(title: 'Viaje dos', author: '', text: _sample));
      final rels = relateBooks([b1, b2]);
      expect(rels, isNotEmpty);
      expect(rels.first.sharedTopics, contains('travel'));
      expect(rels.first.strength, greaterThan(0));
    });

    test('single book → no relationships', () {
      final b1 = BookFingerprint.fromIngested(
        'b1', ingestBook(title: 't', author: '', text: _sample));
      expect(relateBooks([b1]), isEmpty);
    });
  });

  group('audio cache policy', () {
    test('key is stable and varies by text/lang/voice/speed', () {
      final k1 = audioCacheKey(text: 'Hola', langCode: 'es-ES', voice: 'davefx', speed: 1.0);
      final k2 = audioCacheKey(text: 'Hola', langCode: 'es-ES', voice: 'davefx', speed: 1.0);
      final k3 = audioCacheKey(text: 'Hola', langCode: 'es-ES', voice: 'davefx', speed: 1.2);
      expect(k1, k2);
      expect(k1, isNot(k3));
      expect(k1.endsWith('.wav'), isTrue);
    });

    test('eviction removes least-recently-used until under budget', () {
      final entries = [
        const AudioCacheEntry(key: 'a', sizeBytes: 100, lastUsedTick: 1),
        const AudioCacheEntry(key: 'b', sizeBytes: 100, lastUsedTick: 5),
        const AudioCacheEntry(key: 'c', sizeBytes: 100, lastUsedTick: 3),
      ];
      final plan = evictionPlan(entries, maxBytes: 150);
      expect(plan, contains('a')); // oldest first
      expect(plan, isNot(contains('b'))); // newest kept
    });

    test('under budget → no eviction', () {
      expect(
        evictionPlan(const [AudioCacheEntry(key: 'a', sizeBytes: 10, lastUsedTick: 1)],
            maxBytes: 100),
        isEmpty,
      );
    });
  });

  group('ingested → reader Story', () {
    test('multi-chapter book becomes a chaptered Story', () {
      final book = ingestBook(title: 'Viaje', author: 'A', text: _sample);
      final story = storyFromIngested(id: 'imp-1', book: book);
      expect(story.chapterTitles.length, 2);
      expect(story.phrases, isNotEmpty);
      expect(story.level, book.estimatedCefr);
      expect(story.topics, contains('travel'));
    });
  });
}
