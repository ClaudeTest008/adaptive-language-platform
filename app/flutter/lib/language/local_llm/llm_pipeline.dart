import '../pipeline.dart';
import '../teacher_brain.dart';
import '../teacher_intelligence.dart';
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
  LlmResponse respond({
    required TeacherBrain brain,
    required ConversationContext context,
    required String userMessage,
    required TeacherSupportMode supportMode,
  }) {
    final plan = intelligence.plan(brain, turn: context.turns.length);
    final prompt = buildTeacherPrompt(
      brain: brain,
      plan: plan,
      context: context,
      userMessage: userMessage,
      supportMode: supportMode,
    );
    final worded = voice.word(plan, context, brain);
    // Language policy is enforced here, never left to the generator: the
    // strict voice gate keeps only target-language sentences for speech, and
    // immersion drops native support entirely.
    final target = brain.identity.targetLanguage;
    final native = brain.identity.nativeLanguage;
    final safeForSpeech = speechSafeText(worded, target, native);
    final display = supportMode == TeacherSupportMode.immersion
        ? (safeForSpeech.isEmpty ? worded : safeForSpeech)
        : worded;

    final nextContext = context
        .withTurn(ConversationTurn(fromLearner: false, text: display))
        .markUsed(worded);
    return LlmResponse(text: display, prompt: prompt, context: nextContext);
  }
}
