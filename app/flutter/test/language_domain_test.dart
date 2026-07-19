import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/relationships.dart';
import 'package:adaptive_language_platform/language/signals.dart';
import 'package:flutter_test/flutter_test.dart';

LanguageNode _chain() {
  const es = LanguageNode(
    tier: LanguageTier.language, slug: 'es', name: 'Spanish');
  const a1 = LanguageNode(
    tier: LanguageTier.level, slug: 'a1', name: 'A1', parent: es);
  const grammar = LanguageNode(
    tier: LanguageTier.skill, slug: 'grammar', name: 'Grammar', parent: a1);
  const verbs = LanguageNode(
    tier: LanguageTier.domain, slug: 'verbs', name: 'Verbs', parent: grammar);
  return const GrammarConceptNode(
    slug: 'ar-verbs',
    name: 'Regular -ar verbs',
    parent: verbs,
    pattern: 'stem + endings',
  );
}

void main() {
  group('language hierarchy', () {
    test('concept ids are hierarchical and stable', () {
      final node = _chain();
      expect(node.conceptId, 'es:a1:grammar:verbs:ar-verbs');
      expect(node.lineageConceptIds, [
        'es',
        'es:a1',
        'es:a1:grammar',
        'es:a1:grammar:verbs',
        'es:a1:grammar:verbs:ar-verbs',
      ]);
    });

    test('skill, cefr and language derived from lineage', () {
      final node = _chain();
      expect(node.skill, LanguageSkill.grammar);
      expect(node.cefr, CefrLevel.a1);
      expect(node.languageCode, 'es');
      expect(node.path.first.skill, isNull); // language root has no skill
    });

    test('tier order violations rejected', () {
      const topic = LanguageNode(
        tier: LanguageTier.topic, slug: 't', name: 'T');
      const badChild = LanguageNode(
        tier: LanguageTier.skill, slug: 's', name: 'S', parent: topic);
      expect(validLanguageHierarchy(badChild), isFalse);
      expect(validLanguageHierarchy(_chain()), isTrue);
    });

    test('tiers may be skipped', () {
      const es = LanguageNode(
        tier: LanguageTier.language, slug: 'es', name: 'Spanish');
      const phrase = PhraseNode(
        slug: 'hola', name: 'hola', text: 'hola', parent: es);
      expect(validLanguageHierarchy(phrase), isTrue);
    });
  });

  group('language knowledge graph', () {
    LanguageKnowledgeGraph graph() {
      final leaf = _chain();
      final nodes = [...leaf.path];
      const tener = 'es:a1:grammar:verbs:tener-states';
      return LanguageKnowledgeGraph(nodes, [
        LanguageRelation(
          from: tener,
          to: 'en:be-adjective',
          type: LanguageRelationType.interferesWith,
          note: 'to-be transfer',
        ),
        LanguageRelation(
          from: tener,
          to: leaf.conceptId,
          type: LanguageRelationType.buildsOn,
        ),
        const LanguageRelation(
          from: 'es:a1:vocab:embarazada',
          to: 'en:embarrassed',
          type: LanguageRelationType.falseFriend,
        ),
      ]);
    }

    test('typed relation queries', () {
      final g = graph();
      expect(g.ofType(LanguageRelationType.interferesWith), hasLength(1));
      expect(
        g.interference('es:a1:grammar:verbs:tener-states'),
        hasLength(1),
      );
      expect(g.interference('es:a1:vocab:embarazada'), hasLength(1));
      expect(g.interference(_chain().conceptId), isEmpty);
    });

    test('projects onto core KnowledgeGraph unchanged contract', () {
      final core = graph().toCoreGraph();
      final leafId = _chain().conceptId;
      // Parent lineage becomes prerequisite.
      expect(
        core[leafId]!.prerequisites,
        contains('es:a1:grammar:verbs'),
      );
      // buildsOn → followUps on source, related both directions.
      const tener = 'es:a1:grammar:verbs:tener-states';
      expect(core[tener]!.followUps, contains(leafId));
      expect(core.relatedTo(leafId), contains(tener));
      // interference endpoints exist as nodes even outside the hierarchy.
      expect(core['en:be-adjective'], isNotNull);
    });
  });

  group('per-skill mastery', () {
    test('skills aggregate independently', () {
      const es = LanguageNode(
        tier: LanguageTier.language, slug: 'es', name: 'Spanish');
      const a1 = LanguageNode(
        tier: LanguageTier.level, slug: 'a1', name: 'A1', parent: es);
      const grammar = LanguageNode(
        tier: LanguageTier.skill, slug: 'grammar', name: 'G', parent: a1);
      const vocab = LanguageNode(
        tier: LanguageTier.skill, slug: 'vocabulary', name: 'V', parent: a1);
      const g1 = LanguageNode(
        tier: LanguageTier.topic, slug: 'g1', name: 'g1', parent: grammar);
      const g2 = LanguageNode(
        tier: LanguageTier.topic, slug: 'g2', name: 'g2', parent: grammar);
      const v1 = LanguageNode(
        tier: LanguageTier.topic, slug: 'v1', name: 'v1', parent: vocab);
      final graph =
          LanguageKnowledgeGraph(const [es, a1, grammar, vocab, g1, g2, v1], const []);

      final mastery = skillMastery({
        g1.conceptId: 0.4,
        g2.conceptId: 0.8,
        v1.conceptId: 0.9,
        'es': 1.0, // above skill tier — ignored
      }, graph);

      expect(mastery[LanguageSkill.grammar], closeTo(0.6, 1e-9));
      expect(mastery[LanguageSkill.vocabulary], closeTo(0.9, 1e-9));
      expect(
        weakestSkills({
          g1.conceptId: 0.4,
          g2.conceptId: 0.8,
          v1.conceptId: 0.9,
        }, graph).first,
        LanguageSkill.grammar,
      );
    });
  });

  group('curriculum seed data', () {
    Curriculum load(String file) => parseCurriculum(
      jsonDecode(File('assets/curriculum/$file').readAsStringSync())
          as Map<String, dynamic>,
    );

    test('Spanish-for-English parses with misconception structure', () {
      final c = load('es-for-en.json');
      expect(c.languageCode, 'es');
      expect(c.nativeLanguage, 'en');

      final tener =
          c.graph['es:a1:grammar:verbs:states:tener-states']
              as GrammarConceptNode;
      expect(tener.transferTraps, isNotEmpty);
      expect(tener.skill, LanguageSkill.grammar);
      expect(tener.cefr, CefrLevel.a1);
      expect(c.graph.interference(tener.conceptId), isNotEmpty);

      // tener pattern family present.
      for (final p in ['tener-hambre', 'tener-sueno', 'tener-miedo', 'tener-frio']) {
        expect(c.graph['${tener.conceptId}:$p'], isA<PhraseNode>());
      }

      // False friend retrievable for the misconception engine.
      expect(
        c.graph
            .interference('es:a1:vocabulary:food:restaurant:embarazada')
            .single
            .type,
        LanguageRelationType.falseFriend,
      );

      // Cultural context relation reaches the conversation scenario.
      expect(
        c.graph.ofType(LanguageRelationType.culturalContext).single.from,
        'es:a1:conversation:ordering-food',
      );

      // All nodes obey tier ordering; core projection works.
      for (final n in c.graph.nodes.values) {
        expect(validLanguageHierarchy(n), isTrue, reason: n.conceptId);
      }
      expect(c.graph.toCoreGraph().nodes, isNotEmpty);
    });

    test('English-for-Spanish parses with pro-drop interference', () {
      final c = load('en-for-es.json');
      expect(c.nativeLanguage, 'es');
      expect(
        c.graph
            .interference(
              'en:a1:grammar:verbs:present-simple:subject-required')
            .single
            .to,
        'es:pro-drop',
      );
      expect(
        (c.graph['en:a1:conversation:introductions'] as ConversationNode)
            .scenario,
        isNotEmpty,
      );
    });

    test('unknown parent and tier violations rejected', () {
      expect(
        () => parseCurriculum({
          'language': {'code': 'es', 'name': 'Spanish'},
          'nativeLanguage': 'en',
          'nodes': [
            {'tier': 'topic', 'slug': 't', 'name': 'T', 'parent': 'es:missing'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
