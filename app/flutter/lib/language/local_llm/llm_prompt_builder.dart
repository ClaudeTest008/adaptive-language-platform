import '../pipeline.dart';
import '../teacher_brain.dart';
import '../teacher_intelligence.dart';
import 'llm_memory.dart';

/// Prompt builder (Phase 25). Pure and deterministic. Converts the teacher's
/// DECISION (a [TeacherResponsePlan] from the Teacher Intelligence Engine) plus
/// the brain and the live conversation context into a structured prompt for a
/// local LLM. The LLM never sees raw application state — only this prompt, and
/// only so it can WORD the teacher's decision naturally. It never decides
/// pedagogy or language policy; those are fixed here.
///
/// No UI code knows the prompt format. Nothing is fabricated: every field is
/// sourced from the brain/plan, omitted when absent.

/// How many prior exchanges are replayed to the model each turn. The
/// conversation context keeps more than this for the app's own use; only this
/// many are re-sent, because with no KV-prefix reuse in the binding every
/// retained turn is re-tokenised on every reply.
const promptHistoryTurns = 6;

/// A structured prompt: a system brief (who the teacher is + this turn's
/// intent), the user turn, and hard constraints the generator must obey.
/// One prior exchange, delivered to the model as a proper chat message.
class LlmChatTurn {
  const LlmChatTurn({required this.fromLearner, required this.text});

  final bool fromLearner;
  final String text;
}

class LlmPrompt {
  const LlmPrompt({
    required this.system,
    required this.user,
    required this.constraints,
    this.history = const [],
  });

  final String system;

  /// The CURRENT learner message — always the newest, always last.
  final String user;

  /// Previous conversation turns, oldest first (conversation repair: the
  /// investigation proved these never reached the model before).
  final List<LlmChatTurn> history;

  /// Machine-checkable rules (language, correction cap, no-repeat list…).
  final LlmConstraints constraints;

  /// Flattened messages for an `AiChatModel`.
  List<String> get lines => [system, user];
}

/// Hard rules the generator must not break — enforced by the pipeline even if
/// a future neural model ignores them.
class LlmConstraints {
  const LlmConstraints({
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.mentorMode,
    required this.maxCorrections,
    this.doNotRepeat = const [],
  });

  final String targetLanguage;
  final String nativeLanguage;

  /// True = English support may be shown (never spoken). False = immersion.
  final bool mentorMode;

  /// Real teachers correct one important thing; this caps it.
  final int maxCorrections;
  final List<String> doNotRepeat;
}

String _pct(double v) => '${(v * 100).round()}%';

/// Builds the prompt for the teacher's next turn.
LlmPrompt buildTeacherPrompt({
  required TeacherBrain brain,
  required TeacherResponsePlan plan,
  required ConversationContext context,
  required String userMessage,
  required TeacherSupportMode supportMode,
  int maxCorrections = 1,
}) {
  final mentor = supportMode == TeacherSupportMode.mentor;
  final b = StringBuffer();

  b.writeln('You are a patient, observant language teacher — not a chatbot. '
      'You word the teaching decision below in natural, warm, non-repetitive '
      'language. You never invent facts about the learner.');
  b.writeln();
  b.writeln('LANGUAGE — CRITICAL: reply ENTIRELY in '
      '${brain.identity.targetLanguageName} '
      '(${brain.identity.targetLanguage}). Every sentence you say must be in '
      '${brain.identity.targetLanguage}. NEVER answer in '
      '${brain.identity.nativeLanguage}.'
      '${mentor ? ' You MAY add ONE short ${brain.identity.nativeLanguage} '
          'translation at the very end, after a "— ", and nothing more.' : ' No '
          '${brain.identity.nativeLanguage} at all (immersion).'}');
  b.writeln();

  if (plan.moment.converse) {
    // Free-conversation turn: react to the learner, do not lecture. This is
    // the default for chat/statements and keeps the tutor human.
    b.writeln('THIS TURN IS A CONVERSATION, not an exercise. React to exactly '
        'what the learner just said, with real interest, and ask ONE natural '
        'follow-up question — all in Spanish. Do NOT correct grammar and do '
        'NOT start a lesson right now. Keep it to 1–2 short sentences.');
    b.writeln('(Keep this focus in mind for later, but do not force it now: '
        '${plan.state.objective}.)');
  } else {
    // Teaching turn — the brain decided WHAT/WHY; the model supplies HOW.
    b.writeln('THIS TURN — intent: ${plan.moment.intent.name}. '
        'Objective: ${plan.state.objective}.');
    if (plan.moment.socraticPrompt != null) {
      b.writeln('Teach by GUIDED DISCOVERY — ask, do not lecture: '
          '"${plan.moment.socraticPrompt}"');
    } else {
      b.writeln('Message to convey (reword naturally, in Spanish): '
          '${plan.moment.message}');
    }
    if (plan.moment.conceptIds.isNotEmpty) {
      final names = plan.moment.conceptIds
          .map((id) => brain.connections.nodes[id]?.name ?? id)
          .where((n) => !n.contains(':'))
          .take(4)
          .toList();
      if (names.isNotEmpty) {
        b.writeln('Connect it to what the learner already knows: '
            '${names.join(', ')}.');
      }
    }
    if (plan.correction != null) {
      b.writeln('Correct exactly ONE thing, praise first: '
          '${plan.correction!.praise} → ${plan.correction!.correction} '
          '(${plan.correction!.why})');
    }
    if (plan.memory != null) {
      b.writeln('You may reference: ${plan.memory!.reference}');
    }
    if (plan.reflection != null) {
      final r = plan.reflection!;
      b.writeln('Close the lesson: '
          '${[
            if (r.improved != null) r.improved,
            if (r.needsWork != null) r.needsWork,
            if (r.next != null) 'Next: ${r.next}',
            if (r.homework != null) r.homework,
          ].whereType<String>().join(' ')}');
    }
  }

  // Grounding facts — real, from the brain.
  b.writeln();
  b.writeln('LEARNER (facts only, never invent more): '
      'level ${brain.facts.cefr}, '
      'vocabulary ${_pct(brain.facts.vocabulary.mastery)}, '
      'confidence ${_pct(brain.profile.confidence.overall)}.');
  if (brain.mentalModels.isNotEmpty) {
    b.writeln('Prefer this mental model over rote rules: '
        '${brain.mentalModels.first.insight}');
  }

  // Anti-repetition: never reuse a phrasing already used this conversation.
  final doNotRepeat = context.usedPhrasings.toList();
  if (doNotRepeat.isNotEmpty) {
    b.writeln('Do NOT reuse these phrasings: '
        '${doNotRepeat.take(6).join(' | ')}');
  }
  b.writeln('Keep it to a few sentences — a micro-lesson, never a wall of '
      'text.');

  // Prefill is the dominant latency cost on device and the binding offers no
  // KV-prefix reuse, so the WHOLE prompt is reprocessed every turn: history
  // length is paid again on each reply. The last few exchanges carry the
  // thread; durable memory (facts, misconceptions, focus) already reaches the
  // model through the packet, so a deep raw transcript buys latency, not
  // recall.
  final recent = context.turns.length > promptHistoryTurns
      ? context.turns.sublist(context.turns.length - promptHistoryTurns)
      : context.turns;

  return LlmPrompt(
    system: b.toString().trim(),
    user: userMessage,
    history: [
      for (final t in recent)
        LlmChatTurn(fromLearner: t.fromLearner, text: t.text),
    ],
    constraints: LlmConstraints(
      targetLanguage: brain.identity.targetLanguage,
      nativeLanguage: brain.identity.nativeLanguage,
      mentorMode: mentor,
      maxCorrections: maxCorrections,
      doNotRepeat: doNotRepeat,
    ),
  );
}
