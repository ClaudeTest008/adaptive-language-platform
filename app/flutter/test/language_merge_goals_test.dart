import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/language/content_merge.dart';
import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/exercises.dart';
import 'package:adaptive_exam_platform/language/ingestion.dart';
import 'package:adaptive_exam_platform/presentation/language_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

ContentCandidate _c(ContentKind kind, String text, {String? translation}) =>
    ContentCandidate(
      id: '${kind.name}:$text',
      kind: kind,
      text: text,
      translation: translation,
    );

void main() {
  final base = _curriculum();

  group('content merge into curriculum', () {
    test('approved vocabulary becomes a usable concept under ingested', () {
      final merged = mergeApprovedContent(base, [
        _c(ContentKind.vocabulary, 'restaurante', translation: 'restaurant'),
      ]);
      final id = 'es:a1:vocabulary:ingested:restaurante';
      final node = merged.graph[id];
      expect(node, isA<VocabularyConceptNode>());
      expect((node as VocabularyConceptNode).lemma, 'restaurante');
      expect(node.translations['en'], 'restaurant');
      // The merged concept generates exercises like any other vocab.
      final exercises = generateExercises(merged.graph, limit: 200);
      expect(exercises.any((e) => e.node.conceptId == id), isTrue);
      // Base is untouched.
      expect(base.graph[id], isNull);
    });

    test('approved phrases/idioms become phrase nodes', () {
      final merged = mergeApprovedContent(base, [
        _c(ContentKind.phrase, 'pequeño restaurante'),
        _c(ContentKind.idiom, 'por favor', translation: 'please'),
      ]);
      expect(
        merged.graph['es:a1:vocabulary:ingested:pequeño-restaurante'],
        isA<PhraseNode>(),
      );
      final favor = merged.graph['es:a1:vocabulary:ingested:por-favor'];
      expect((favor as PhraseNode?)?.translation, 'please');
    });

    test('nothing approved leaves the curriculum unchanged', () {
      final merged = mergeApprovedContent(base, const []);
      expect(merged.graph.nodes.length, base.graph.nodes.length);
      // Mapped candidates (already in curriculum) do not re-add.
      final mappedOnly = mergeApprovedContent(base, [
        const ContentCandidate(
          id: 'vocabulary:manzana',
          kind: ContentKind.vocabulary,
          text: 'manzana',
          conceptId: 'es:a1:vocabulary:food:fruit:manzana',
        ),
      ]);
      expect(mappedOnly.graph.nodes.length, base.graph.nodes.length);
    });

    test('approved sentences synthesize a story', () {
      final story = storyFromApproved(
        [
          _c(ContentKind.sentence, 'Yo tengo hambre.', translation: 'I am hungry.'),
          _c(ContentKind.sentence, 'Ella habla español.',
              translation: 'She speaks Spanish.'),
        ],
        languageCode: 'es',
        level: CefrLevel.a1,
      );
      expect(story, isNotNull);
      expect(story!.phrases, hasLength(2));
      expect(story.phrases.first.text, 'Yo tengo hambre.');
      // Fewer than two sentences → no story.
      expect(
        storyFromApproved(
          [_c(ContentKind.sentence, 'Solo una.')],
          languageCode: 'es',
          level: CefrLevel.a1,
        ),
        isNull,
      );
    });
  });

  group('learner goals wiring', () {
    test('minutes drive availableMinutesProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(availableMinutesProvider), 25);
      container.read(learnerGoalsProvider.notifier).setMinutes(45);
      expect(container.read(availableMinutesProvider), 45);
      // Clamped to a sane range.
      container.read(learnerGoalsProvider.notifier).setMinutes(999);
      expect(container.read(availableMinutesProvider), 60);
    });

    test('target level is settable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(learnerGoalsProvider).targetLevel, CefrLevel.a2);
      container.read(learnerGoalsProvider.notifier).setTargetLevel(CefrLevel.b1);
      expect(container.read(learnerGoalsProvider).targetLevel, CefrLevel.b1);
    });
  });

  group('approve flows candidate into the live curriculum', () {
    ProviderContainer make() {
      final container = ProviderContainer(
        overrides: [
          curriculumProvider.overrideWith((ref) async {
            final approved = ref.watch(approvedContentProvider);
            return mergeApprovedContent(base, approved);
          }),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('studio approve adds to approvedContent and merges', () async {
      final container = make();
      final studio = container.read(contentStudioProvider.notifier);
      // Warm curriculum for ingest().
      await container.read(curriculumProvider.future);
      studio.ingest(
        'María quiere un pequeño restaurante en Sevilla. '
        'El camarero habla español despacio.',
      );
      final novel = container
          .read(contentStudioProvider)
          .result!
          .candidates
          .firstWhere(
            (c) => c.kind == ContentKind.vocabulary && !c.mapped,
          );
      await studio.approve(novel.id);

      expect(
        container.read(approvedContentProvider).any((c) => c.id == novel.id),
        isTrue,
      );
      final merged = await container.read(curriculumProvider.future);
      final id = 'es:a1:vocabulary:ingested:${_slug(novel.text)}';
      expect(merged.graph[id], isNotNull);
    });

    test('reject removes it again', () async {
      final container = make();
      final studio = container.read(contentStudioProvider.notifier);
      await container.read(curriculumProvider.future);
      studio.ingest('El camarero habla español despacio.');
      final novel = container
          .read(contentStudioProvider)
          .result!
          .candidates
          .firstWhere((c) => c.kind == ContentKind.vocabulary);
      await studio.approve(novel.id);
      expect(container.read(approvedContentProvider), isNotEmpty);
      await studio.reject(novel.id);
      expect(container.read(approvedContentProvider), isEmpty);
    });
  });
}

String _slug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ ]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), '-');
