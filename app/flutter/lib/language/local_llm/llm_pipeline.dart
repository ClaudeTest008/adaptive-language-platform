import '../message_intent.dart';
import '../pipeline.dart';
import '../teacher_brain.dart';
import '../teacher_intelligence.dart';
import '../teacher_packet.dart';
import 'llm_memory.dart';
import 'llm_prompt_builder.dart';
import 'local_llm.dart';

/// The response pipeline (Phase 25):
///
///   TeacherBrain → TeacherIntelligenceEngine → TeacherResponsePlan →
///   PromptBuilder → Local LLM (deterministic voice today) → Language Pipeline
///   (mentor/immersion + strict voice gate) → Piper.
///
/// Pure orchestration: it turns the teacher's decision into a natural,
/// language-policy-correct reply. The brain decides, the voice words, the
/// pipeline speaks. Nothing here invents learner data.
class LlmResponse {
  const LlmResponse({
    required this.text,
    required this.prompt,
    required this.context,
  });

  /// The teacher's worded reply (target-language body may be spoken; native
  /// support, if any, is shown only in mentor mode).
  final String text;

  /// The structured prompt built for a (future) neural model — exposed for
  /// diagnostics and for the real LLM to consume.
  final LlmPrompt prompt;

  /// The conversation context after this turn (phrasing marked used).
  final ConversationContext context;
}

class LlmPipeline {
  const LlmPipeline({
    this.voice = const DeterministicTeacherVoice(),
    this.intelligence = const TeacherIntelligenceEngine(),
  });

  final DeterministicTeacherVoice voice;
  final TeacherIntelligenceEngine intelligence;

  /// Produces the teacher's next reply from the live brain + conversation.
  ///
  /// Phase 36: [generate] is the real neural wording generator (on-device
  /// GGUF). When provided and successful its text is used; on null/empty the
  /// deterministic voice words the SAME plan — the neural model only ever
  /// changes wording, never the teacher's decision, and failure never
  /// invents anything.
  ///
  /// Conversation repair: [learnerIntent] (deterministic classification of
  /// the message) now shapes the plan; [learnerFacts] are facts the learner
  /// explicitly shared — questions about them are answered deterministically
  /// (the truth never depends on a model); [packet] is the full TeacherPacket,
  /// serialized once into the system prompt so the model finally sees the
  /// teacher's structured knowledge.
  Future<LlmResponse> respond({
    required TeacherBrain brain,
    required ConversationContext context,
    required String userMessage,
    required TeacherSupportMode supportMode,
    Future<String?> Function(LlmPrompt prompt)? generate,
    LearnerIntent? learnerIntent,
    Map<String, String> learnerFacts = const {},
    TeacherPacket? packet,
    bool learnerProducedTarget = false,
  }) async {
    final intent = learnerIntent ?? classifyLearnerMessage(userMessage);
    final plan = intelligence.plan(
      brain,
      turn: context.turns.length,
      learnerIntent: intent,
      producedTarget: learnerProducedTarget,
      turnsSinceCorrection: context.turnsSinceCorrection,
      lastCorrectedConceptId: context.lastCorrectedConceptId,
      learnerMessage: userMessage,
    );
    final base = buildTeacherPrompt(
      brain: brain,
      plan: plan,
      context: context,
      userMessage: userMessage,
      supportMode: supportMode,
    );
    // Slim packet (Phase 2/6): only the wording-relevant, non-duplicative
    // facts reach the model — the full telemetry inflated prefill without
    // changing the reply.
    final brief = packet == null ? '' : serializeTeacherPacketBrief(packet);
    final prompt = brief.isEmpty
        ? base
        : LlmPrompt(
            system: '${base.system}\n\n$brief',
            user: base.user,
            history: base.history,
            constraints: base.constraints,
          );

    // 1 · Questions about explicitly-shared facts get the deterministic
    //     truth — a model may word teaching, never learner facts.
    final factAnswer = answerFromFacts(userMessage, learnerFacts);
    var worded = factAnswer ?? voice.word(plan, context, brain);
    if (factAnswer == null && generate != null) {
      try {
        final neural = await generate(prompt);
        final text = neural?.trim() ?? '';
        // A small model copies whatever dominates its context: on device it
        // returned an earlier fallback line verbatim. A reply that merely
        // repeats something already said is worse than the fallback, so it
        // is rejected and the deterministic wording stands.
        final echoesHistory = context.turns.any(
          (t) => !t.fromLearner && t.text.trim() == text,
        );
        if (text.isNotEmpty && !echoesHistory) worded = text;
      } catch (_) {
        // Neural generator failure is never fatal — the deterministic voice
        // has already worded the same plan.
      }
    }
    // Language policy is enforced here, never left to the generator: the
    // strict voice gate keeps only target-language sentences for speech, and
    // immersion drops native support entirely.
    final target = brain.identity.targetLanguage;
    final native = brain.identity.nativeLanguage;
    final safeForSpeech = speechSafeText(worded, target, native);
    final display = supportMode == TeacherSupportMode.immersion
        ? (safeForSpeech.isEmpty ? worded : safeForSpeech)
        : worded;

    var nextContext = context
        .withTurn(ConversationTurn(fromLearner: false, text: display))
        .markUsed(worded);
    // Restart the correction clock only when a correction actually went out,
    // so the next turns stay conversational.
    if (plan.correction != null) {
      nextContext = nextContext.withCorrection(plan.correction!.conceptId);
    }
    return LlmResponse(text: display, prompt: prompt, context: nextContext);
  }
}
