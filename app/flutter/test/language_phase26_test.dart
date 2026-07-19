import 'package:adaptive_exam_platform/language/conversation_continuity.dart';
import 'package:adaptive_exam_platform/language/curriculum_intelligence.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/error_taxonomy.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_exam_platform/language/misconceptions.dart';
import 'package:adaptive_exam_platform/language/pipeline.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/teacher_packet.dart';
import 'package:flutter_test/flutter_test.dart';

// A tiny real curriculum: hambre (known) → sueño/miedo (related, unmet);
// subjuntivo requires presente (weak).
const _hambre = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
const _miedo = 'es:a1:grammar:tener:miedo';
const _presente = 'es:a1:grammar:verbs:presente';
const _subjuntivo = 'es:a1:grammar:verbs:subjuntivo';

LanguageNode _node(String slug, LanguageNode? parent,
        {List<String> prereqs = const []}) =>
    LanguageNode(
      tier: LanguageTier.grammarConcept,
      slug: slug,
      name: slug.replaceAll('-', ' '),
      parent: parent,
      prerequisites: prereqs,
    );

LanguageKnowledgeGraph _graph() {
  final es = LanguageNode(tier: LanguageTier.language, slug: 'es', name: 'Spanish');
  final a1 = LanguageNode(tier: LanguageTier.level, slug: 'a1', name: 'A1', parent: es);
  final gram = LanguageNode(tier: LanguageTier.skill, slug: 'grammar', name: 'Grammar', parent: a1);
  final tener = LanguageNode(tier: LanguageTier.domain, slug: 'tener', name: 'tener family', parent: gram);
  final verbs = LanguageNode(tier: LanguageTier.domain, slug: 'verbs', name: 'verbs', parent: gram);
  return LanguageKnowledgeGraph([
    es, a1, gram, tener, verbs,
    _node('hambre', tener),
    _node('sueno', tener),
    _node('miedo', tener),
    _node('presente', verbs),
    _node('subjuntivo', verbs, prereqs: [_presente]),
  ], const [
    LanguageRelation(from: _hambre, to: _sueno, type: LanguageRelationType.relatedTo),
    LanguageRelation(from: _hambre, to: _miedo, type: LanguageRelationType.buildsOn),
  ]);
}

const _names = {
  _hambre: 'hambre', _sueno: 'sueno', _miedo: 'miedo',
  _presente: 'presente', _subjuntivo: 'subjuntivo',
};

TeacherBrain _brain({
  Map<String, double> mastery = const {_hambre: 0.9, _presente: 0.3},
  String? currentConceptId,
}) => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: DateTime(2026, 7, 18),
    nativeLanguage: 'en',
    targetLanguage: 'es',
    targetLanguageName: 'Spanish',
    baseLevel: 'A1',
    longTermGoal: 'Reach A2 Spanish',
    skillMastery: const {LanguageSkill.grammar: 0.5},
    conceptMastery: mastery,
    conceptNames: _names,
    misconceptions: const [],
    accuracy: 0.6,
    totalAnswered: 30,
    learningDna: const [],
    historyDays: const [],
    vocabularyPoolSize: 100,
    relations: _graph().relations,
    currentConceptId: currentConceptId,
  ),
);

void main() {
  const curriculum = CurriculumIntelligenceEngine();

  group('curriculum intelligence', () {
    test('node view: prerequisites, successors, difficulty, value', () {
      final n = curriculum.node(_presente, _graph(), _brain());
      expect(n.successors, contains(_subjuntivo));
      expect(n.difficulty, greaterThan(0));
      expect(n.teachingValue, greaterThan(0));
    });

    test('missing prerequisite resolved from real mastery', () {
      // presente mastery 0.3 < threshold → blocks subjuntivo.
      expect(
        curriculum.missingPrerequisite(_subjuntivo, _graph(), _brain()),
        _presente,
      );
      // Mastered prerequisite → nothing missing.
      expect(
        curriculum.missingPrerequisite(
          _subjuntivo, _graph(), _brain(mastery: const {_presente: 0.9}),
        ),
        isNull,
      );
    });

    test('nextToStudy: focus prerequisite first, deterministic', () {
      final brain = _brain(currentConceptId: _subjuntivo);
      final next = curriculum.nextToStudy(_graph(), brain);
      expect(next, _presente);
      expect(curriculum.nextToStudy(_graph(), brain), next); // deterministic
    });

    test('almostMastered finds the 0.35–0.8 band', () {
      final brain = _brain(mastery: const {_hambre: 0.9, _presente: 0.6});
      expect(curriculum.almostMastered(brain), _presente);
    });

    test('journeys derive from engaged domains with measured progress', () {
      final brain = _brain(mastery: const {
        _hambre: 0.9, _sueno: 0.6, _miedo: 0.1,
      });
      final journeys = curriculum.journeys(_graph(), brain);
      expect(journeys, isNotEmpty);
      final tener = journeys.firstWhere((j) => j.id.contains('tener'));
      expect(tener.progress, greaterThan(0));
      expect(tener.currentStage, isNotNull); // miedo not done
    });

    test('untouched learner → no journeys, nothing fabricated', () {
      expect(curriculum.journeys(_graph(), _brain(mastery: const {})), isEmpty);
    });
  });

  group('conversation continuity', () {
    test('open question, promise, roleplay and exercise extracted from real '
        'turns only', () {
      var ctx = const ConversationContext(
        topic: 'travel',
        roleplay: 'hotel check-in',
        activeExercise: 'describe your room',
      );
      ctx = ctx
          .withTurn(const ConversationTurn(fromLearner: false, text: 'Hola.'))
          .withTurn(const ConversationTurn(
              fromLearner: false,
              text: 'Next time we will visit the market. ¿Tienes maletas?'));
      final s = summarizeConversation(ctx);
      expect(s.openQuestions, hasLength(1));
      expect(s.promises, hasLength(1));
      expect(s.roleplay!.scenario, 'hotel check-in');
      expect(s.pendingExercise!.description, 'describe your room');
      expect(s.arc.currentTopic, 'travel');
    });

    test('continuation resumes the highest-priority real thread', () {
      final withRoleplay = summarizeConversation(
        const ConversationContext(roleplay: 'hotel check-in'),
      );
      expect(buildContinuation(withRoleplay).thread, 'roleplay');

      final topicOnly = summarizeConversation(
        const ConversationContext(topic: 'travel'),
      );
      final c = buildContinuation(topicOnly);
      expect(c.thread, 'topic');
      expect(c.opener, contains('travel'));
    });

    test('empty conversation → no fabricated memory', () {
      final c = buildContinuation(
        summarizeConversation(const ConversationContext()),
      );
      expect(c.opener, isNull);
      expect(c.thread, isNull);
    });

    test('an answered question is not open', () {
      var ctx = const ConversationContext();
      ctx = ctx
          .withTurn(const ConversationTurn(
              fromLearner: false, text: '¿Tienes hambre?'))
          .withTurn(const ConversationTurn(fromLearner: true, text: 'Sí.'));
      expect(summarizeConversation(ctx).openQuestions, isEmpty);
    });
  });

  group('error taxonomy', () {
    Misconception misc({LanguageRelationType? rel, String source = 'en:be'}) =>
        Misconception(
          id: 'x', conceptId: _hambre, nativeLanguage: 'en',
          interferenceSource: source, pattern: 'p', explanation: 'e',
          relationType: rel, lastSeen: DateTime(2026, 7, 18),
        );

    test('classifies from captured fields, each with its own strategy', () {
      expect(
        classifyMisconception(misc(rel: LanguageRelationType.falseFriend)),
        ErrorCategory.falseFriend,
      );
      expect(
        classifyMisconception(misc(rel: LanguageRelationType.interferesWith)),
        ErrorCategory.englishTransfer,
      );
      final a = strategyFor(ErrorCategory.falseFriend).approach;
      final b = strategyFor(ErrorCategory.careless).approach;
      expect(a, isNot(equals(b)));
    });

    test('attempt classification: mastered+fast=careless, slow=lapse, '
        'low-confidence spoken=confidence', () {
      expect(
        classifyAttempt(previouslyMastered: true, fastResponse: true),
        ErrorCategory.careless,
      );
      expect(
        classifyAttempt(previouslyMastered: true, fastResponse: false),
        ErrorCategory.memoryLapse,
      );
      expect(
        classifyAttempt(
          previouslyMastered: false, fastResponse: false,
          spoken: true, speakingConfidence: 0.2,
        ),
        ErrorCategory.confidence,
      );
    });
  });

  group('teacher packet', () {
    test('packet is fully derived and serializes deterministically', () {
      final brain = _brain(
        mastery: const {_hambre: 0.9, _presente: 0.3},
        currentConceptId: _subjuntivo,
      );
      final ctx = const ConversationContext(topic: 'travel');
      TeacherPacket build() => buildTeacherPacket(
        brain: brain, graph: _graph(), context: ctx,
        supportMode: TeacherSupportMode.mentor,
      );
      final p = build();
      expect(p.objective, brain.objectives.current);
      expect(p.currentNode, isNotNull);
      expect(p.knownConcepts, isNotEmpty);
      expect(p.languagePolicy, contains('native notes'));
      final s1 = serializeTeacherPacket(p);
      final s2 = serializeTeacherPacket(build());
      expect(s1, s2); // deterministic
      expect(s1, contains('OBJECTIVE:'));
      expect(s1, contains('LANGUAGE POLICY:'));
    });

    test('packetPrompt merges the slim brief (facts) into the prompt, policy intact',
        () {
      final brain = _brain();
      final packet = buildTeacherPacket(
        brain: brain, graph: _graph(),
        context: const ConversationContext(),
        supportMode: TeacherSupportMode.immersion,
        learnerFacts: const {'name': 'John', 'city': 'London'},
      );
      final prompt = packetPrompt(
        brain: brain, packet: packet,
        context: const ConversationContext(),
        userMessage: 'Hola',
        supportMode: TeacherSupportMode.immersion,
      );
      // Base teaching decision survives (lowercase from the base builder)…
      expect(prompt.system, contains('Objective:'));
      // …and the slim brief carries the learner facts (not the old telemetry).
      expect(prompt.system, contains('SOBRE EL ALUMNO'));
      expect(prompt.system, contains('John'));
      expect(prompt.system, isNot(contains('RECOMMEND (')));
      expect(prompt.constraints.mentorMode, isFalse);
    });
  });
}
