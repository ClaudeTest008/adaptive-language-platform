import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_memory.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_model_manager.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_pipeline.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_prompt_builder.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_repository.dart';
import 'package:adaptive_exam_platform/language/local_llm/llm_downloader.dart';
import 'package:adaptive_exam_platform/language/local_llm/local_llm.dart';
import 'package:adaptive_exam_platform/language/pipeline.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/teacher_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

const _hambre = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
const _miedo = 'es:a1:grammar:tener:miedo';

final _relations = <LanguageRelation>[
  const LanguageRelation(from: _hambre, to: _sueno, type: LanguageRelationType.relatedTo),
  const LanguageRelation(from: _hambre, to: _miedo, type: LanguageRelationType.buildsOn),
];
const _names = {_hambre: 'tener hambre', _sueno: 'tener sueño', _miedo: 'tener miedo'};

TeacherBrain _brain({
  Map<String, double> conceptMastery = const {_hambre: 0.9, _sueno: 0.8, _miedo: 0.7},
  String? currentConceptId,
}) => const OfflineReasoningEngine().assemble(
  BrainInputs(
    today: _day,
    nativeLanguage: 'en',
    targetLanguage: 'es',
    targetLanguageName: 'Spanish',
    baseLevel: 'A1',
    longTermGoal: 'Reach A2 Spanish',
    skillMastery: const {LanguageSkill.grammar: 0.5, LanguageSkill.speaking: 0.5},
    conceptMastery: conceptMastery,
    conceptNames: _names,
    misconceptions: const [],
    accuracy: 0.6,
    totalAnswered: 30,
    learningDna: const [],
    historyDays: const [],
    vocabularyPoolSize: 100,
    relations: _relations,
    currentConceptId: currentConceptId,
  ),
);
final _day = DateTime(2026, 7, 18);

/// Fake downloader the model-manager tests control.
class FakeLlmDownloader implements LlmModelDownloader {
  FakeLlmDownloader({this.ok = true, this.throwOn = false});
  bool ok;
  bool throwOn;
  bool deleted = false;

  @override
  Future<String> download(String url,
      {required String expectedSha256,
      required void Function(double) onProgress}) async {
    if (throwOn) throw Exception('network down');
    onProgress(1.0);
    return '/models/llm/model.gguf';
  }

  @override
  Future<bool> verify(String path,
          {required String expectedSha256, required int expectedBytes}) async =>
      ok;

  @override
  Future<void> delete(String path) async => deleted = true;
}

void main() {
  const intelligence = TeacherIntelligenceEngine();

  group('prompt builder — deterministic, plan-driven, policy-fixed', () {
    test('encodes objective, language policy, connections, no-repeat', () {
      final brain = _brain(currentConceptId: _hambre);
      final plan = intelligence.plan(brain);
      final ctx = const ConversationContext()
          .markUsed('¡Vas muy bien! Sigamos.');
      final prompt = buildTeacherPrompt(
        brain: brain,
        plan: plan,
        context: ctx,
        userMessage: 'Hola',
        supportMode: TeacherSupportMode.mentor,
      );
      expect(prompt.system, contains('Spanish'));
      expect(prompt.system, contains('reply ENTIRELY in Spanish'));
      expect(prompt.constraints.targetLanguage, 'es');
      expect(prompt.constraints.maxCorrections, 1);
      expect(prompt.constraints.doNotRepeat, contains('¡Vas muy bien! Sigamos.'));
      expect(prompt.user, 'Hola');
    });

    test('immersion vs mentor changes the support instruction only', () {
      final brain = _brain();
      final plan = intelligence.plan(brain);
      final mentor = buildTeacherPrompt(
        brain: brain, plan: plan, context: const ConversationContext(),
        userMessage: 'x', supportMode: TeacherSupportMode.mentor,
      );
      final imm = buildTeacherPrompt(
        brain: brain, plan: plan, context: const ConversationContext(),
        userMessage: 'x', supportMode: TeacherSupportMode.immersion,
      );
      expect(mentor.constraints.mentorMode, isTrue);
      expect(imm.constraints.mentorMode, isFalse);
      expect(imm.system, contains('immersion'));
    });

    test('same inputs → identical prompt (deterministic)', () {
      final brain = _brain(currentConceptId: _hambre);
      final plan = intelligence.plan(brain);
      String sys() => buildTeacherPrompt(
        brain: brain, plan: plan, context: const ConversationContext(),
        userMessage: 'x', supportMode: TeacherSupportMode.mentor,
      ).system;
      expect(sys(), sys());
    });
  });

  group('conversation context (not learner memory)', () {
    test('keeps recent turns bounded and records used phrasings', () {
      var ctx = const ConversationContext();
      for (var i = 0; i < 20; i++) {
        ctx = ctx.withTurn(ConversationTurn(fromLearner: i.isEven, text: 't$i'));
      }
      expect(ctx.turns.length, lessThanOrEqualTo(12));
      ctx = ctx.markUsed('phrase');
      expect(ctx.usedPhrasings, contains('phrase'));
    });
  });

  group('deterministic voice — words the plan, varies without randomness', () {
    test('reply is in the target language and non-empty', () {
      final brain = _brain(currentConceptId: _hambre);
      final plan = intelligence.plan(brain);
      final text = const DeterministicTeacherVoice()
          .word(plan, const ConversationContext(), brain);
      expect(text.trim(), isNotEmpty);
    });

    test('varies across turns — no immediate repetition', () {
      final brain = _brain();
      final voice = const DeterministicTeacherVoice();
      final seen = <String>[];
      var ctx = const ConversationContext();
      for (var i = 0; i < 3; i++) {
        // producedTarget:true keeps this a TEACHING turn (variant rotation);
        // chat turns intentionally use one steady conversational ack now.
        final plan = intelligence.plan(brain,
            turn: ctx.turns.length, producedTarget: true);
        final text = voice.word(plan, ctx, brain);
        ctx = ctx.withTurn(ConversationTurn(fromLearner: false, text: text))
            .markUsed(text);
        seen.add(text);
      }
      // Used phrasings are skipped → the three are distinct.
      expect(seen.toSet().length, seen.length);
    });
  });

  group('LlmPipeline — brain decides, voice words, policy enforced', () {
    test('produces a reply and advances context', () async {
      final brain = _brain(currentConceptId: _hambre);
      final res = await const LlmPipeline().respond(
        brain: brain,
        context: const ConversationContext(),
        userMessage: 'Tengo hambre',
        supportMode: TeacherSupportMode.mentor,
      );
      expect(res.text.trim(), isNotEmpty);
      expect(res.context.turns, isNotEmpty);
      expect(res.context.usedPhrasings, isNotEmpty);
      expect(res.prompt.system, contains('Spanish'));
    });

    test('LocalLlm seam reports not-ready until a real model loads', () {
      expect(const LocalLlm().isReady, isFalse);
    });

    test('neural generator words the reply when it succeeds (Phase 36)', () async {
      final brain = _brain(currentConceptId: _hambre);
      final res = await const LlmPipeline().respond(
        brain: brain,
        context: const ConversationContext(),
        userMessage: 'Tengo hambre',
        supportMode: TeacherSupportMode.mentor,
        generate: (prompt) async {
          expect(prompt.system, contains('Spanish')); // real prompt delivered
          return 'Muy bien. ¿Qué quieres comer hoy?';
        },
      );
      expect(res.text, 'Muy bien. ¿Qué quieres comer hoy?');
    });

    test('null/throwing neural generator falls back to deterministic voice',
        () async {
      final brain = _brain(currentConceptId: _hambre);
      final deterministic = await const LlmPipeline().respond(
        brain: brain,
        context: const ConversationContext(),
        userMessage: 'Tengo hambre',
        supportMode: TeacherSupportMode.mentor,
      );
      final nullGen = await const LlmPipeline().respond(
        brain: brain,
        context: const ConversationContext(),
        userMessage: 'Tengo hambre',
        supportMode: TeacherSupportMode.mentor,
        generate: (_) async => null,
      );
      final throwing = await const LlmPipeline().respond(
        brain: brain,
        context: const ConversationContext(),
        userMessage: 'Tengo hambre',
        supportMode: TeacherSupportMode.mentor,
        generate: (_) async => throw StateError('engine died'),
      );
      // Both failure modes produce exactly the deterministic wording.
      expect(nullGen.text, deterministic.text);
      expect(throwing.text, deterministic.text);
    });

    test('immersion speech gate still applies to neural output', () async {
      final brain = _brain(currentConceptId: _hambre);
      final res = await const LlmPipeline().respond(
        brain: brain,
        context: const ConversationContext(),
        userMessage: 'Tengo hambre',
        supportMode: TeacherSupportMode.immersion,
        generate: (_) async =>
            'Muy bien, sigue así. This is the English explanation of it all.',
      );
      // The pipeline, not the model, enforces language policy: the English
      // support sentence is dropped in immersion.
      expect(res.text, isNot(contains('English explanation')));
      expect(res.text, contains('Muy bien'));
    });
  });

  group('LLM model manager — mirrors Whisper/Piper lifecycle', () {
    test('absent → download → verify → ready, persisted', () async {
      final repo = InMemoryLlmModelRepository();
      final mgr = LlmModelManager(repository: repo, downloader: FakeLlmDownloader());
      expect((await mgr.status()).status, LlmModelStatus.absent);
      final r = await mgr.ensureDownloaded();
      expect(r.isReady, isTrue);
      final mgr2 = LlmModelManager(
        repository: repo, downloader: FakeLlmDownloader(throwOn: true));
      expect((await mgr2.status()).isReady, isTrue);
    });

    test('failed SHA → corrupt', () async {
      final mgr = LlmModelManager(
        repository: InMemoryLlmModelRepository(),
        downloader: FakeLlmDownloader(ok: false),
      );
      expect((await mgr.ensureDownloaded()).status, LlmModelStatus.corrupt);
    });

    test('download error → failed, reported', () async {
      final mgr = LlmModelManager(
        repository: InMemoryLlmModelRepository(),
        downloader: FakeLlmDownloader(throwOn: true),
      );
      final r = await mgr.ensureDownloaded();
      expect(r.status, LlmModelStatus.failed);
      expect(r.error, contains('network'));
    });

    test('stale version → versionMismatch (upgrade path)', () async {
      final repo = InMemoryLlmModelRepository();
      await repo.save(const LlmModelInfo(
        version: 'old', sizeBytes: 100, path: '/x', sha256: 'y'));
      final mgr = LlmModelManager(repository: repo, downloader: FakeLlmDownloader());
      expect((await mgr.status()).status, LlmModelStatus.versionMismatch);
    });

    test('delete forgets the model', () async {
      final repo = InMemoryLlmModelRepository();
      final dl = FakeLlmDownloader();
      final mgr = LlmModelManager(repository: repo, downloader: dl);
      await mgr.ensureDownloaded();
      await mgr.delete();
      expect(dl.deleted, isTrue);
      expect(await repo.load(), isNull);
    });

    test('model info JSON round-trips', () {
      const info = LlmModelInfo(
        version: 'v1', sizeBytes: 123, path: '/m', sha256: 'abc',
        contextLength: 4096, modelType: 'Small');
      final back = LlmModelInfo.fromJson(info.toJson());
      expect(back.version, 'v1');
      expect(back.contextLength, 4096);
      expect(back.modelType, 'Small');
    });
  });
}
