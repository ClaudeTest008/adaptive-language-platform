import '../../ai/chat_model.dart';
import '../teacher_brain.dart';
import '../teacher_intelligence.dart';
import 'llm_memory.dart';

/// The local LLM (Phase 25). Two pieces:
///
/// 1. [LocalLlm] — an [AiChatModel] seam for a future on-device GGUF model.
///    It words a built prompt into natural text on a background isolate. The
///    real llama.cpp/GGUF binding is the device-gated step (needs a native
///    inference plugin + on-device verification), staged exactly as Piper and
///    Whisper were. Until then it reports not-ready and the deterministic voice
///    below does the wording, so the teacher works fully offline today.
///
/// 2. [DeterministicTeacherVoice] — a pure, offline generator that words the
///    teacher's structured decision (a [TeacherResponsePlan]) directly, with
///    variation-without-randomness. This is the shipping generator; a neural
///    model can replace it behind [LocalLlm] without changing anything above.
///
/// In both cases the Teacher Brain decides WHAT/WHY/WHEN; this only supplies
/// HOW to word it. Nothing is invented — every line is grounded in the plan.
class LocalLlm implements AiChatModel {
  const LocalLlm({this.ready = false});

  /// True once a real GGUF model is loaded in the isolate (device step).
  final bool ready;

  @override
  String get providerName => 'local-llm';

  bool get isReady => ready;

  @override
  Future<String> complete(List<AiMessage> messages) async {
    // Real inference is the device-gated seam; without a loaded model the
    // caller falls back to the deterministic voice (never a crash, never a
    // fabricated answer).
    throw StateError('Local GGUF model not loaded — use the deterministic '
        'voice or install the model.');
  }
}

/// Deterministic, offline wording of the teacher's plan. Pure.
class DeterministicTeacherVoice {
  const DeterministicTeacherVoice();

  /// Words [plan] for the learner. Variation comes from the conversation
  /// position + intent (never randomness), and phrasings already used this
  /// conversation are skipped so the teacher does not repeat itself.
  String word(
    TeacherResponsePlan plan,
    ConversationContext context,
    TeacherBrain brain,
  ) {
    final es = brain.identity.targetLanguage == 'es';
    final names = _familyNames(plan, brain);
    final variants = _variantsFor(plan, es, names, brain);
    return _pick(variants, plan, context);
  }

  List<String> _familyNames(TeacherResponsePlan plan, TeacherBrain brain) => [
    for (final id in plan.moment.conceptIds)
      if (brain.connections.nodes[id]?.name case final n?)
        if (!n.contains(':')) n,
  ].take(3).toList();

  List<String> _variantsFor(
    TeacherResponsePlan plan,
    bool es,
    List<String> names,
    TeacherBrain brain,
  ) {
    final family = names.isEmpty ? '' : names.join(', ');
    switch (plan.moment.intent) {
      case TeacherIntent.discover:
        return es
            ? [
                if (family.isNotEmpty) 'Mira estos juntos: $family. ¿Qué tienen en común?',
                if (family.isNotEmpty) 'Fíjate en $family. ¿Ves el patrón?',
                '¿Qué notas aquí? Tómate un momento.',
              ]
            : [
                if (family.isNotEmpty) 'Look at these together: $family. What do they share?',
                if (family.isNotEmpty) 'Notice $family. See the pattern?',
                'What do you notice here? Take a moment.',
              ];
      case TeacherIntent.connect:
        return es
            ? [
                if (family.isNotEmpty) 'Esto pertenece a la misma familia que $family.',
                if (family.isNotEmpty) 'Conecta esto con lo que ya sabes: $family.',
                'Esto se conecta con lo que ya conoces.',
              ]
            : [
                if (family.isNotEmpty) 'This belongs to the same family as $family.',
                if (family.isNotEmpty) 'Connect this to what you know: $family.',
                'This connects to what you already know.',
              ];
      case TeacherIntent.correct:
        final c = plan.correction;
        final tail = c == null ? '' : ' ${c.correction} ${c.why}';
        return es
            ? [
                'Bien dicho. Solo un detalle:$tail',
                'Muy bien. Afinemos una cosa:$tail',
                'Se entiende. Un pequeño ajuste:$tail',
              ]
            : [
                'Well said. Just one thing:$tail',
                'Nicely done. Let’s tighten one thing:$tail',
                'That’s clear. One small fix:$tail',
              ];
      case TeacherIntent.review:
        return es
            ? [
                'Antes de seguir, repasemos un momento lo que ya sabes.',
                'Demos un paso atrás y afiancemos lo aprendido.',
                'Sin prisa: revisemos juntos antes de avanzar.',
              ]
            : [
                'Before we go on, let’s revisit what you know.',
                'Let’s step back and lock in what we’ve built.',
                'No rush — a quick review before anything new.',
              ];
      case TeacherIntent.encourage:
        return es
            ? [
                '¡Vas muy bien! Sigamos.',
                'Me gusta tu progreso. Continuemos.',
                '¡Un paso más y lo tienes!',
              ]
            : [
                'You’re doing well — let’s keep going.',
                'I like your progress. Onward.',
                'One more step and it’s yours.',
              ];
      case TeacherIntent.reflect:
      case TeacherIntent.previewNext:
        final next = plan.reflection?.next;
        return es
            ? [
                'Hoy avanzaste. La próxima vez: ${next ?? 'seguimos construyendo'}.',
                'Buen trabajo hoy. Después veremos ${next ?? 'lo siguiente'}.',
              ]
            : [
                'You moved forward today. Next: ${next ?? 'we keep building'}.',
                'Good work today. Next we’ll look at ${next ?? 'what follows'}.',
              ];
      case TeacherIntent.greet:
      case TeacherIntent.warmUp:
        return es
            ? [
                '¡Hola de nuevo! ¿Seguimos donde lo dejamos?',
                '¡Qué bueno verte! ¿Empezamos?',
              ]
            : [
                'Good to see you again! Pick up where we left off?',
                'Welcome back! Shall we begin?',
              ];
      case TeacherIntent.practice:
      case TeacherIntent.challenge:
        return es
            ? [
                'Tu turno: dilo con tus propias palabras.',
                'Inténtalo ahora, sin miedo.',
              ]
            : [
                'Your turn — say it in your own words.',
                'Give it a try now.',
              ];
    }
  }

  /// Deterministic pick: rotate by conversation position + intent, and skip any
  /// phrasing already used this conversation.
  String _pick(
    List<String> variants,
    TeacherResponsePlan plan,
    ConversationContext context,
  ) {
    final options = variants.where((v) => v.isNotEmpty).toList();
    if (options.isEmpty) return plan.moment.message;
    final base = (context.turns.length + plan.moment.intent.index) %
        options.length;
    for (var i = 0; i < options.length; i++) {
      final candidate = options[(base + i) % options.length];
      if (!context.usedPhrasings.contains(candidate)) return candidate;
    }
    return options[base];
  }
}
