import 'connections.dart';
import 'learning_profile.dart';
import 'local_llm/llm_memory.dart';
import 'message_intent.dart';
import 'teacher_brain.dart';
import 'teaching_style.dart';

/// Teacher Intelligence Engine (Phase 24). Pure, deterministic, offline. It
/// consumes ONLY the [TeacherBrain] and decides WHAT to teach, WHY, and WHEN —
/// the pedagogy. A future local LLM (P25) decides only HOW to word it; this
/// engine remains the teacher. No UI, no persistence, no learner state of its
/// own. Nothing is fabricated: when the brain lacks data, plans stay empty or
/// null and say why.
///
/// Core philosophy encoded here: invisible, Socratic, connection-first
/// teaching. The teacher guides discovery and ties every step to something the
/// learner already understands, rather than lecturing isolated facts.

/// What the teacher is trying to accomplish with a turn. Every teacher turn
/// serves exactly one intent — never idle chatter.
enum TeacherIntent {
  greet,
  warmUp,
  review,
  connect,
  discover, // Socratic — guide the learner to see a pattern
  practice,
  challenge,
  encourage,
  correct,
  reflect,
  previewNext,
}

/// The natural arc of a lesson. The conversation state advances through these.
enum LessonStage {
  greeting,
  warmUp,
  review,
  connection,
  discovery,
  practice,
  challenge,
  reflection,
  homework,
  preview,
}

/// The teacher's pacing choice for the next move — adaptive, never random.
enum PacingAction {
  slowDown,
  review,
  introduceConcept,
  tellStory,
  practiceSpeaking,
  increaseChallenge,
  recoverConfidence,
  stayTheCourse,
}

/// Derived conversation state (no duplicate learner state — all read from the
/// brain plus the turn count the caller tracks).
class ConversationState {
  const ConversationState({
    required this.stage,
    required this.objective,
    this.activeConceptId,
    this.topic,
    required this.confidence,
    this.energy = 0.5,
  });

  final LessonStage stage;
  final String objective;
  final String? activeConceptId;
  final String? topic;

  /// Learner confidence in the active area (0…1), from the profile.
  final double confidence;

  /// Conversation energy/engagement (0…1) — from motivation momentum.
  final double energy;
}

/// A short connection-first teaching beat, with the evidence behind it.
class TeachingMoment {
  const TeachingMoment({
    required this.intent,
    required this.message,
    this.conceptIds = const [],
    this.socraticPrompt,
    this.rationale = '',
    this.converse = false,
  });

  final TeacherIntent intent;
  final String message;
  final List<String> conceptIds;

  /// A guided-discovery question, when this moment teaches Socratically.
  final String? socraticPrompt;

  /// Why the teacher chose this — explainable.
  final String rationale;

  /// True when this is a free-conversation turn: the teacher should REACT to
  /// what the learner just said and ask a natural follow-up, NOT deliver a
  /// prepared lesson beat or a correction. The prompt builder switches to a
  /// conversational instruction, and no correction is attached.
  final bool converse;
}

/// One correction the teacher will actually make. Real teachers correct ONE
/// important thing, praise first, and explain why — referencing prior learning.
class CorrectionPlan {
  const CorrectionPlan({
    required this.conceptId,
    required this.praise,
    required this.correction,
    required this.why,
  });

  final String conceptId;
  final String praise;
  final String correction;
  final String why;
}

/// End-of-lesson reflection: what improved, what to work on, what's next.
class ReflectionPlan {
  const ReflectionPlan({
    this.improved,
    this.needsWork,
    this.next,
    this.homework,
  });

  final String? improved;
  final String? needsWork;
  final String? next;
  final String? homework;
}

/// A noticed opportunity the teacher may act on (invisible teaching / curiosity
/// / connection). Ranked; the top one drives the next moment.
class TeachingOpportunity {
  const TeachingOpportunity({
    required this.intent,
    required this.reason,
    required this.priority,
    this.conceptIds = const [],
  });

  final TeacherIntent intent;
  final String reason;

  /// Lower = act sooner.
  final int priority;
  final List<String> conceptIds;
}

/// A short, natural reference to prior learning ("Remember tener hambre?"),
/// drawn from real connections/history — never invented.
class ConversationMemory {
  const ConversationMemory(this.reference, {this.conceptIds = const []});

  final String reference;
  final List<String> conceptIds;
}

/// The full plan for the teacher's next turn.
class TeacherResponsePlan {
  const TeacherResponsePlan({
    required this.state,
    required this.moment,
    required this.pacing,
    this.correction,
    this.memory,
    this.reflection,
  });

  final ConversationState state;
  final TeachingMoment moment;
  final PacingAction pacing;
  final CorrectionPlan? correction;
  final ConversationMemory? memory;

  /// Present only when the lesson is closing.
  final ReflectionPlan? reflection;
}

/// The top-level decision: the intent, the concept, and the reason. This is
/// what a local LLM would receive to word naturally.
class TeacherDecision {
  const TeacherDecision({
    required this.intent,
    required this.rationale,
    this.conceptId,
  });

  final TeacherIntent intent;
  final String rationale;
  final String? conceptId;
}

/// The engine. Stateless; every method is a pure function of the brain (plus
/// the caller-supplied turn index, which is not learner state).
class TeacherIntelligenceEngine {
  const TeacherIntelligenceEngine();

  /// Maps a turn index onto the lesson arc. Discovery/practice occupy the
  /// middle; reflection/preview close it.
  LessonStage stageForTurn(int turn, {int lessonLength = 8}) {
    const arc = [
      LessonStage.greeting,
      LessonStage.warmUp,
      LessonStage.review,
      LessonStage.connection,
      LessonStage.discovery,
      LessonStage.practice,
      LessonStage.challenge,
      LessonStage.reflection,
    ];
    if (turn <= 0) return LessonStage.greeting;
    if (turn >= lessonLength - 1) return LessonStage.reflection;
    return arc[turn.clamp(0, arc.length - 1)];
  }

  ConversationState conversationState(TeacherBrain brain, {int turn = 0}) {
    final activeId = brain.objectives.currentConceptId;
    final conf = activeId == null
        ? brain.profile.confidence.overall
        : brain.profile.confidence.overall;
    final energy = ((brain.profile.motivation.momentum + 1) / 2).clamp(0.0, 1.0);
    return ConversationState(
      stage: stageForTurn(turn),
      objective: brain.objectives.current,
      activeConceptId: activeId,
      topic: brain.interests.isEmpty ? null : brain.interests.first.topic,
      confidence: conf,
      energy: energy,
    );
  }

  /// Ranks the opportunities the brain currently affords — recovery and active
  /// misconceptions first, then connections, curiosity, challenge.
  List<TeachingOpportunity> opportunities(TeacherBrain brain) {
    final ops = <TeachingOpportunity>[];

    if (brain.pedagogy?.recoveryMode ?? false) {
      ops.add(TeachingOpportunity(
        intent: TeacherIntent.review,
        reason: brain.pedagogy!.rationale,
        priority: 0,
      ));
    }

    final focusId = brain.objectives.currentConceptId;
    if (focusId != null) {
      ops.add(TeachingOpportunity(
        intent: TeacherIntent.correct,
        reason: 'Active focus: ${brain.objectives.current}.',
        priority: 1,
        conceptIds: [focusId],
      ));
    }

    final suggestion = brain.connections.suggestions.isEmpty
        ? null
        : brain.connections.suggestions.first;
    if (suggestion != null) {
      ops.add(TeachingOpportunity(
        intent: TeacherIntent.connect,
        reason:
            'Teach outward from ${suggestion.anchorName} into '
            '${suggestion.relatedNames.join(', ')}.',
        priority: 2,
        conceptIds: [suggestion.anchorId, ...suggestion.relatedIds],
      ));
    }

    if (brain.mentalModels.isNotEmpty) {
      final m = brain.mentalModels.first;
      ops.add(TeachingOpportunity(
        intent: TeacherIntent.discover,
        reason: 'A pattern is ready to be discovered: ${m.title}.',
        priority: 3,
        conceptIds: [m.anchorConceptId, ...m.relatedConceptIds],
      ));
    }

    if (brain.curiosities.isNotEmpty) {
      ops.add(TeachingOpportunity(
        intent: TeacherIntent.encourage,
        reason: brain.curiosities.first.text,
        priority: 4,
        conceptIds: brain.curiosities.first.conceptIds,
      ));
    }

    ops.sort((a, b) => a.priority.compareTo(b.priority));
    return ops;
  }

  /// The top-level teaching decision from the current brain state.
  TeacherDecision decide(TeacherBrain brain) {
    final ops = opportunities(brain);
    if (ops.isEmpty) {
      return const TeacherDecision(
        intent: TeacherIntent.encourage,
        rationale: 'Nothing pressing — keep momentum with light practice.',
      );
    }
    final top = ops.first;
    return TeacherDecision(
      intent: top.intent,
      rationale: top.reason,
      conceptId: top.conceptIds.isEmpty ? null : top.conceptIds.first,
    );
  }

  /// Adaptive pacing — decided from difficulty fit, motivation and profile.
  PacingAction pacing(TeacherBrain brain) {
    final ped = brain.pedagogy;
    if (ped?.recoveryMode ?? false) return PacingAction.recoverConfidence;
    if (brain.profile.motivation.state == MotivationState.strained) {
      return PacingAction.recoverConfidence;
    }
    switch (ped?.difficulty) {
      case DifficultyFit.tooDifficult:
        return PacingAction.slowDown;
      case DifficultyFit.tooEasy:
        return PacingAction.increaseChallenge;
      default:
        break;
    }
    if (brain.profile.has(LearningTraitKind.needsRepetition)) {
      return PacingAction.review;
    }
    if (brain.profile.has(LearningTraitKind.strongReader)) {
      return PacingAction.tellStory;
    }
    if (brain.profile.has(LearningTraitKind.avoidsSpeaking)) {
      return PacingAction.practiceSpeaking;
    }
    return PacingAction.stayTheCourse;
  }

  /// A natural reference to prior learning, from real connections/history.
  /// Null when there is nothing genuine to recall.
  /// Spanish-first, like every other teacher-authored line: the target-language
  /// half is what the learner reads and what the voice may speak, and the
  /// English half is support that the speech gate keeps out of the audio. A
  /// bare English opener here used to become the spoken body of the bubble.
  ConversationMemory? memory(TeacherBrain brain) {
    if (brain.connectionMoments.isNotEmpty) {
      final m = brain.connectionMoments.first;
      return ConversationMemory(
        '¿Recuerdas? — ${m.text}',
        conceptIds: m.conceptIds,
      );
    }
    if (brain.lessonHistory.isNotEmpty) {
      final last = brain.lessonHistory.last;
      return ConversationMemory('La última vez: ${last.objective}.');
    }
    return null;
  }

  /// The single correction worth making now — praise first, one thing, with a
  /// connection-anchored reason. Null when nothing needs correcting.
  CorrectionPlan? correction(TeacherBrain brain) {
    final weak = brain.facts.grammar
        .where((g) => g.status == GrammarStatus.weak)
        .toList()
      ..sort((a, b) => a.confidence.compareTo(b.confidence));
    if (weak.isEmpty) return null;
    final g = weak.first;
    // Spanish-first, teacher-natural. Never dump the internal concept label
    // (g.name is an English curriculum tag like "Physical and emotional
    // states" — the exact robotic leak seen on device). The "why" anchors to
    // a Spanish family leaf the learner already holds.
    final family = _familyOf(brain, g.conceptId);
    final why = family.isEmpty
        ? 'es parte de un patrón que estamos construyendo juntos.'
        : 'funciona igual que ${family.first.toLowerCase()}.';
    return CorrectionPlan(
      conceptId: g.conceptId,
      praise: 'Bien dicho, se entiende la idea.',
      correction: 'Afinemos un pequeño detalle.',
      why: why,
    );
  }

  /// Builds the connection-first, often-Socratic moment for [decision].
  TeachingMoment moment(TeacherBrain brain, TeacherDecision decision) {
    final family = decision.conceptId == null
        ? const <String>[]
        : _familyOf(brain, decision.conceptId!);
    switch (decision.intent) {
      // Brain-driven moment text is authored SPANISH-FIRST: it seeds the
      // wording model's "message to convey" and is the deterministic voice's
      // fallback, so English here leaked into spoken replies. Concept family
      // names are Spanish leaf names (post depth-filter), safe to weave in.
      case TeacherIntent.discover:
        // Invisible teaching: show, ask, let them see it — do not announce.
        return TeachingMoment(
          intent: decision.intent,
          message: family.length >= 2
              ? 'Fíjate en estos juntos: ${family.take(3).join(', ')}.'
              : 'Aquí tienes un ejemplo. Léelo en voz alta y fíjate cómo suena.',
          conceptIds: decision.conceptId == null ? const [] : [decision.conceptId!],
          socraticPrompt: family.length >= 2
              ? '¿Qué tienen en común? ¿Te recuerda a algo que ya sabes?'
              : '¿Qué patrón notas?',
          rationale: decision.rationale,
        );
      case TeacherIntent.connect:
        return TeachingMoment(
          intent: decision.intent,
          message: family.isEmpty
              ? 'Esto se conecta con lo que ya sabes.'
              : 'Esto es de la misma familia que ${family.take(3).join(', ')}.',
          conceptIds: family.isEmpty ? const [] : family.take(4).toList(),
          rationale: decision.rationale,
        );
      case TeacherIntent.review:
        return TeachingMoment(
          intent: decision.intent,
          message: 'Antes de seguir, repasemos un momento lo que ya vimos, '
              'sin prisa.',
          rationale: decision.rationale,
        );
      case TeacherIntent.correct:
        return TeachingMoment(
          intent: decision.intent,
          message: 'Bien dicho. Déjame señalar un pequeño detalle.',
          conceptIds: decision.conceptId == null ? const [] : [decision.conceptId!],
          rationale: decision.rationale,
        );
      case TeacherIntent.encourage:
        return TeachingMoment(
          intent: decision.intent,
          message: brain.curiosities.isEmpty
              ? '¡Vas muy bien! Sigamos así.'
              : brain.curiosities.first.text,
          rationale: decision.rationale,
        );
      case TeacherIntent.greet:
      case TeacherIntent.warmUp:
        return TeachingMoment(
          intent: decision.intent,
          message: '¡Hola de nuevo! ¿Seguimos donde lo dejamos?',
          rationale: decision.rationale,
        );
      case TeacherIntent.practice:
      case TeacherIntent.challenge:
        return TeachingMoment(
          intent: decision.intent,
          message: 'Tu turno: dilo con tus propias palabras.',
          conceptIds: decision.conceptId == null ? const [] : [decision.conceptId!],
          rationale: decision.rationale,
        );
      case TeacherIntent.reflect:
      case TeacherIntent.previewNext:
        return TeachingMoment(
          intent: decision.intent,
          message: 'Un repaso rápido antes de terminar.',
          rationale: decision.rationale,
        );
    }
  }

  /// End-of-lesson reflection from measured outcomes — empty fields when
  /// unmeasured, never invented.
  ReflectionPlan reflection(TeacherBrain brain) {
    final improved = brain.facts.skills.values
        .where((s) => s.trend == Trend.improving)
        .toList();
    final weak = brain.facts.grammar
        .where((g) => g.status == GrammarStatus.weak)
        .toList();
    return ReflectionPlan(
      improved: improved.isEmpty
          ? null
          : 'Today your ${improved.first.skill.name} moved forward.',
      needsWork: weak.isEmpty ? null : 'Keep an eye on ${weak.first.name}.',
      next: brain.objectives.secondary,
      homework: brain.connections.suggestions.isEmpty
          ? null
          : 'Practice: ${brain.connections.suggestions.first.relatedNames.take(2).join(', ')}.',
    );
  }

  /// The complete next-turn plan. [learnerIntent] is the deterministic
  /// classification of what the learner just said (conversation repair): the
  /// teacher now reacts to the message instead of planning blind.
  /// [learnerHasProduced] is true once the learner has actually written or
  /// said something correctable — corrections are gated on it, so the teacher
  /// never opens a conversation by correcting.
  /// [producedTarget] is true only when the learner's message is an actual
  /// attempt in the TARGET language (Spanish) — the only thing that can be
  /// corrected. An English chat message ("my wife is Mexican") is conversation,
  /// not production, so it must never trigger a grammar correction. This is the
  /// fix for the tutor "correcting instead of conversing": the planner was
  /// picking `correct` on every turn because the demo brain always has an
  /// active weak concept, and every message was flagged correctable.
  /// How many learner turns must pass between corrections, and how long the
  /// same point stays off-limits after being corrected. Real teachers let
  /// most slips go and revisit a point later — correcting every utterance is
  /// what made the tutor feel like a grammar checker instead of a partner.
  static const correctionGapTurns = 2;
  static const sameConceptGapTurns = 4;

  TeacherResponsePlan plan(
    TeacherBrain brain, {
    int turn = 0,
    LearnerIntent? learnerIntent,
    bool learnerHasProduced = false,
    bool producedTarget = false,
    int turnsSinceCorrection = ConversationContext.neverCorrected,
    String? lastCorrectedConceptId,
  }) {
    final state = conversationState(brain, turn: turn);
    final closing = state.stage == LessonStage.reflection;

    // Correction cadence: even a real Spanish attempt is only corrected when
    // enough has been said since the last correction, and the same concept is
    // not re-corrected back-to-back.
    final pending = correction(brain);
    final sameConceptTooSoon = pending != null &&
        pending.conceptId == lastCorrectedConceptId &&
        turnsSinceCorrection < sameConceptGapTurns;
    final correctionAllowed = producedTarget &&
        turnsSinceCorrection >= correctionGapTurns &&
        !sameConceptTooSoon;

    // 1 · Learner-driven moments beat brain-driven planning (greeting,
    //     confusion, example/grammar/roleplay requests…).
    final learnerMoment = _momentForLearner(brain, learnerIntent, turn: turn);

    // 2 · Free conversation: a statement / open question / unclassified turn
    //     that is NOT a Spanish attempt is CHAT — react and follow up, never
    //     lecture or correct. This keeps the tutor conversational by default.
    final isChat = learnerMoment == null &&
        turn > 0 &&
        !producedTarget &&
        (learnerIntent == LearnerIntent.statement ||
            learnerIntent == LearnerIntent.question ||
            learnerIntent == LearnerIntent.unknown ||
            learnerIntent == null);

    TeachingMoment chosen;
    TeacherDecision decision;
    if (learnerMoment != null) {
      chosen = learnerMoment;
      decision = TeacherDecision(
        intent: learnerMoment.intent,
        rationale: learnerMoment.rationale,
        conceptId:
            learnerMoment.conceptIds.isEmpty ? null : learnerMoment.conceptIds.first,
      );
    } else if (isChat) {
      chosen = _converseMoment(brain);
      decision = TeacherDecision(
        intent: chosen.intent,
        rationale: chosen.rationale,
      );
    } else if (turn <= 0) {
      decision = const TeacherDecision(
        intent: TeacherIntent.greet,
        rationale: 'Every lesson opens with a real greeting.',
      );
      chosen = moment(brain, decision);
    } else {
      // Teaching turn (Spanish production or the lesson's own beat). Correct
      // only when the learner produced correctable Spanish AND the cadence
      // allows it — otherwise teach forward and let the slip pass.
      decision = decide(brain);
      if (decision.intent == TeacherIntent.correct && !correctionAllowed) {
        final ops = opportunities(brain)
            .where((o) => o.intent != TeacherIntent.correct)
            .toList();
        decision = ops.isEmpty
            ? const TeacherDecision(
                intent: TeacherIntent.discover,
                rationale: 'Teach forward — nothing to correct yet.',
              )
            : TeacherDecision(
                intent: ops.first.intent,
                rationale: ops.first.reason,
                conceptId:
                    ops.first.conceptIds.isEmpty ? null : ops.first.conceptIds.first,
              );
      }
      chosen = moment(brain, decision);
    }

    return TeacherResponsePlan(
      state: state,
      moment: chosen,
      pacing: pacing(brain),
      correction: decision.intent == TeacherIntent.correct && correctionAllowed
          ? pending
          : null,
      memory: memory(brain),
      reflection: closing ? reflection(brain) : null,
    );
  }

  /// A free-conversation beat: react to the learner and keep the exchange
  /// flowing. The concrete reaction is produced by the model from the learner's
  /// actual message; this only sets the intent + a Spanish fallback line.
  TeachingMoment _converseMoment(TeacherBrain brain) => const TeachingMoment(
        intent: TeacherIntent.encourage,
        message: '¡Qué interesante! Cuéntame un poco más.',
        converse: true,
        rationale: 'The learner is chatting — converse naturally, no correction.',
      );

  /// Builds the moment when the learner's message itself demands a specific
  /// reaction. Null = nothing special, fall back to brain-driven planning.
  TeachingMoment? _momentForLearner(
    TeacherBrain brain,
    LearnerIntent? intent, {
    int turn = 0,
  }) {
    if (intent == null) return null;
    final focusId = brain.objectives.currentConceptId;
    final family = focusId == null ? const <String>[] : _familyOf(brain, focusId);
    final anchor = family.isEmpty ? null : family.first.toLowerCase();
    switch (intent) {
      case LearnerIntent.greeting:
        return TeachingMoment(
          intent: turn <= 1 ? TeacherIntent.greet : TeacherIntent.warmUp,
          message: '¡Hola! Me alegro de verte. ¿Cómo estás hoy?',
          rationale: 'The learner greeted — greet back, warmly.',
        );
      case LearnerIntent.farewell:
        return TeachingMoment(
          intent: TeacherIntent.reflect,
          message: '¡Hasta pronto! Hoy avanzaste de verdad.',
          rationale: 'The learner is leaving — close the lesson kindly.',
        );
      case LearnerIntent.confusion:
        return TeachingMoment(
          intent: TeacherIntent.discover,
          message: 'Tranquilo, lo explico de otra manera con un ejemplo'
              '${anchor == null ? '' : ', empezando por $anchor'}. '
              '— In English: no problem, a simpler explanation with a concrete example'
              '${anchor == null ? '' : ' starting from $anchor, which you '
                  'already know'}.',
          conceptIds: focusId == null ? const [] : [focusId],
          rationale: 'The learner said they did not understand — re-explain '
              'differently, never repeat the same wording.',
        );
      case LearnerIntent.exampleRequest:
        return TeachingMoment(
          intent: TeacherIntent.practice,
          message: 'Claro, aquí tienes otro ejemplo distinto. Léelo en voz '
              'alta. — A fresh example, different from the last one.',
          conceptIds: focusId == null ? const [] : [focusId],
          rationale: 'The learner asked for another example — give a new one.',
        );
      case LearnerIntent.grammarRequest:
        return TeachingMoment(
          intent: TeacherIntent.connect,
          message: 'Buena pregunta, vamos a verlo con calma'
              '${anchor == null ? '' : ', conectándolo con $anchor'}. '
              '— In English: good question, here is how it actually works in real speech.',
          conceptIds: focusId == null ? const [] : [focusId],
          rationale: 'The learner asked for a grammar explanation.',
        );
      case LearnerIntent.vocabularyRequest:
      case LearnerIntent.translationRequest:
        return TeachingMoment(
          intent: TeacherIntent.connect,
          message: 'Vamos a verlo con una frase natural. — I will give you '
              'the word and one natural sentence that uses it.',
          rationale: 'The learner asked about a word or translation.',
        );
      case LearnerIntent.roleplayRequest:
        return TeachingMoment(
          intent: TeacherIntent.practice,
          message: '¡Perfecto! Vamos a practicar en una escena real.',
          rationale: 'The learner asked to roleplay — start a scene.',
        );
      case LearnerIntent.practiceRequest:
      case LearnerIntent.conversationRequest:
        return TeachingMoment(
          intent: TeacherIntent.practice,
          message: 'Muy bien — tu turno. Te propongo algo corto para empezar.',
          rationale: 'The learner asked to practice.',
        );
      case LearnerIntent.question:
      case LearnerIntent.statement:
      case LearnerIntent.unknown:
        return null; // brain-driven planning handles these
    }
  }

  /// The family (same-domain concepts) around [conceptId], from the connection
  /// graph — the raw material for connection-first teaching.
  List<String> _familyOf(TeacherBrain brain, String conceptId) {
    final domain = domainAncestor(conceptId);
    final names = <String>[];
    for (final c in brain.connections.clusters) {
      if (c.id != domain) continue;
      final focusDepth = conceptId.split(':').length;
      for (final id in c.memberIds) {
        if (id == conceptId) continue;
        // Only sibling/leaf concepts read naturally in a sentence. Ancestor
        // tiers ("Verbs", "Present tense") leaked into replies as robotic
        // lists — the investigation's "internal node names" defect.
        if (id.split(':').length < focusDepth) continue;
        final name = brain.connections.nodes[id]?.name;
        if (name != null && !names.contains(name)) names.add(name);
      }
    }
    return names;
  }
}
