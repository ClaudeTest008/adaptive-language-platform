// ignore_for_file: dangling_library_doc_comments
/// Conversation-scoped memory for the local LLM (Phase 25).
///
/// This is NOT learner memory — the [TeacherBrain] owns all durable learner
/// state. This holds only the ephemeral context of the current conversation:
/// recent exchanges, the active topic/roleplay, pending questions, the active
/// exercise, and phrasings already used (so the teacher does not repeat
/// itself). Nothing here is persisted; it dies with the conversation.

/// One exchange in the running conversation.
class ConversationTurn {
  const ConversationTurn({required this.fromLearner, required this.text});

  final bool fromLearner;
  final String text;
}

/// The live conversation context handed to the prompt builder.
class ConversationContext {
  const ConversationContext({
    this.turns = const [],
    this.topic,
    this.roleplay,
    this.pendingQuestion,
    this.activeExercise,
    this.usedPhrasings = const {},
    this.turnsSinceCorrection = neverCorrected,
    this.lastCorrectedConceptId,
  });

  /// Recent exchanges, oldest-first (bounded by [withTurn]).
  final List<ConversationTurn> turns;
  final String? topic;
  final String? roleplay;
  final String? pendingQuestion;
  final String? activeExercise;

  /// Openings/corrections/encouragements already used — the LLM must vary,
  /// so these become "do not repeat" constraints.
  final Set<String> usedPhrasings;

  /// Learner turns since the teacher last corrected something, and what it
  /// corrected. Correction CADENCE is conversation-scoped, not learner state:
  /// a good teacher lets mistakes go by rather than interrupting every
  /// sentence, and never hammers the same point twice in a row.
  final int turnsSinceCorrection;
  final String? lastCorrectedConceptId;

  static const _maxTurns = 12;

  /// No correction has happened yet in this conversation.
  static const neverCorrected = 99;

  ConversationContext withTurn(ConversationTurn turn) {
    final next = [...turns, turn];
    return copyWith(
      turns: next.length > _maxTurns
          ? next.sublist(next.length - _maxTurns)
          : next,
      // Only the learner's own turns advance the correction clock.
      turnsSinceCorrection: turn.fromLearner
          ? (turnsSinceCorrection >= neverCorrected
              ? neverCorrected
              : turnsSinceCorrection + 1)
          : turnsSinceCorrection,
    );
  }

  /// Records that the teacher just corrected [conceptId], restarting the
  /// cadence clock.
  ConversationContext withCorrection(String? conceptId) => copyWith(
        turnsSinceCorrection: 0,
        lastCorrectedConceptId: conceptId,
        clearLastCorrected: conceptId == null,
      );

  ConversationContext markUsed(String phrasing) =>
      copyWith(usedPhrasings: {...usedPhrasings, phrasing});

  ConversationContext copyWith({
    List<ConversationTurn>? turns,
    String? topic,
    String? roleplay,
    String? pendingQuestion,
    String? activeExercise,
    Set<String>? usedPhrasings,
    int? turnsSinceCorrection,
    String? lastCorrectedConceptId,
    bool clearLastCorrected = false,
  }) => ConversationContext(
    turns: turns ?? this.turns,
    topic: topic ?? this.topic,
    roleplay: roleplay ?? this.roleplay,
    pendingQuestion: pendingQuestion ?? this.pendingQuestion,
    activeExercise: activeExercise ?? this.activeExercise,
    usedPhrasings: usedPhrasings ?? this.usedPhrasings,
    turnsSinceCorrection: turnsSinceCorrection ?? this.turnsSinceCorrection,
    lastCorrectedConceptId: clearLastCorrected
        ? null
        : (lastCorrectedConceptId ?? this.lastCorrectedConceptId),
  );
}
