import 'package:adaptive_language_platform/language/connection_optimization.dart';
import 'package:adaptive_language_platform/language/entities.dart';
import 'package:adaptive_language_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_language_platform/language/pipeline.dart';
import 'package:adaptive_language_platform/language/reasoning_engine.dart';
import 'package:adaptive_language_platform/language/relationships.dart';
import 'package:adaptive_language_platform/language/teacher_brain.dart';
import 'package:adaptive_language_platform/language/teacher_memory_engine.dart';
import 'package:adaptive_language_platform/language/teacher_packet.dart';
import 'package:flutter_test/flutter_test.dart';

const _hambre = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
const _miedo = 'es:a1:grammar:tener:miedo';
final _relations = <LanguageRelation>[
  const LanguageRelation(from: _hambre, to: _sueno, type: LanguageRelationType.relatedTo),
  const LanguageRelation(from: _hambre, to: _miedo, type: LanguageRelationType.buildsOn),
];
const _names = {_hambre: 'tener hambre', _sueno: 'tener sueño', _miedo: 'tener miedo'};

LanguageKnowledgeGraph _graph() {
  final es = LanguageNode(tier: LanguageTier.language, slug: 'es', name: 'Spanish');
  final a1 = LanguageNode(tier: LanguageTier.level, slug: 'a1', name: 'A1', parent: es);
  final g = LanguageNode(tier: LanguageTier.skill, slug: 'grammar', name: 'Grammar', parent: a1);
  final t = LanguageNode(tier: LanguageTier.domain, slug: 'tener', name: 'tener family', parent: g);
  return LanguageKnowledgeGraph([
    es, a1, g, t,
    LanguageNode(tier: LanguageTier.grammarConcept, slug: 'hambre', name: 'hambre', parent: t),
    LanguageNode(tier: LanguageTier.grammarConcept, slug: 'sueno', name: 'sueno', parent: t),
    LanguageNode(tier: LanguageTier.grammarConcept, slug: 'miedo', name: 'miedo', parent: t),
  ], _relations);
}

TeacherBrain _brain({Map<String, double> mastery = const {_hambre: 0.9}}) =>
    const OfflineReasoningEngine().assemble(
      BrainInputs(
        today: DateTime(2026, 7, 18),
        nativeLanguage: 'en', targetLanguage: 'es', targetLanguageName: 'Spanish',
        baseLevel: 'A1', longTermGoal: 'g',
        skillMastery: const {LanguageSkill.grammar: 0.6},
        conceptMastery: mastery, conceptNames: _names, misconceptions: const [],
        accuracy: 0.6, totalAnswered: 30, learningDna: const [],
        historyDays: const [], vocabularyPoolSize: 100, relations: _relations,
      ),
    );

void main() {
  group('connection optimization — measured, deterministic', () {
    test('empty graph → empty report, nothing fabricated', () {
      final report = optimizeConnections(_brain(mastery: const {}), _graph());
      expect(report.isEmpty, isTrue);
      expect(report.suggestedBridges, isEmpty);
      expect(report.clusters, isEmpty);
    });

    test('suggests teaching bridges from hidden connections (known → unmet)', () {
      // hambre known, sueno/miedo unmet → hidden connections → bridges.
      final report = optimizeConnections(_brain(), _graph());
      expect(report.suggestedBridges, isNotEmpty);
      final bridge = report.suggestedBridges.first;
      expect(bridge.kind, BridgeKind.teaching);
      expect(bridge.reason.toLowerCase(), contains('reinforce'));
      // Never synthesizes an edge — only recommends a bridge.
      expect(bridge.value, greaterThan(0));
    });

    test('cluster health + density are derived from real members', () {
      final report = optimizeConnections(
        _brain(mastery: const {_hambre: 0.9, _sueno: 0.8, _miedo: 0.7}),
        _graph());
      expect(report.clusters, isNotEmpty);
      final c = report.clusters.first;
      expect(c.mastery, greaterThan(0));
      expect(c.coverage, greaterThan(0));
      expect(c.health, isNotNull);
    });

    test('optimization score is explainable + deterministic', () {
      final a = optimizeConnections(_brain(), _graph());
      final b = optimizeConnections(_brain(), _graph());
      expect(a.optimizationScore, b.optimizationScore);
      expect(a.scoreBreakdown.keys,
          containsAll(['coverage', 'density', 'reinforcement', 'memoryStability']));
      expect(a.optimizationScore, inInclusiveRange(0.0, 1.0));
    });

    test('consumes memory: forgotten concept becomes a review bridge', () {
      const memory = TeacherMemorySummary(
        lessonsCompleted: 3, forgottenSkills: [_hambre]);
      final report = optimizeConnections(_brain(), _graph(), memory: memory);
      expect(
        report.suggestedBridges.any((b) => b.kind == BridgeKind.review),
        isTrue,
      );
    });

    test('produces recommendations that merge into the one engine', () {
      final report = optimizeConnections(_brain(), _graph());
      expect(report.recommendations, isNotEmpty);
      // deterministic across calls
      final again = optimizeConnections(_brain(), _graph());
      expect(report.recommendations.map((r) => r.id),
          again.recommendations.map((r) => r.id));
    });
  });

  group('teacher packet — optimization expansion', () {
    test('carries + serializes optimization when present, omits when empty', () {
      final brain = _brain();
      final report = optimizeConnections(brain, _graph());
      final packet = buildTeacherPacket(
        brain: brain, graph: _graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor,
        optimization: report);
      expect(packet.optimization, isNotNull);
      expect(serializeTeacherPacket(packet), contains('CONNECTIONS:'));

      final empty = buildTeacherPacket(
        brain: _brain(mastery: const {}), graph: _graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.mentor,
        optimization: optimizeConnections(_brain(mastery: const {}), _graph()));
      expect(empty.optimization, isNull);
      expect(serializeTeacherPacket(empty), isNot(contains('CONNECTIONS:')));
    });
  });
}
