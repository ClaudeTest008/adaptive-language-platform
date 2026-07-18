import 'local_llm/llm_memory.dart';

/// Conversation Continuity Engine (Phase 26). Pure, deterministic, offline.
///
/// NOT learner memory — the Teacher Brain owns that. This engine remembers
/// CONVERSATIONS: unfinished discussions, running roleplays, promises the
/// teacher made, pending exercises, personal details the learner actually
/// mentioned. Everything is extracted from the real transcript in
/// [ConversationContext]; nothing is ever invented — if it was never said,
/// it is not remembered.

/// A theme the conversation has actually touched.
class ConversationTopic {
  const ConversationTopic(this.topic, {this.mentions = 1});

  final String topic;
  final int mentions;
}

/// A question the teacher asked that the learner has not answered yet.
class OpenQuestion {
  const OpenQuestion(this.question);

  final String question;
}

/// Something the teacher said it would do ("next time we'll…").
class TeacherPromise {
  const TeacherPromise(this.promise);

  final String promise;
}

/// An exercise set up but not completed this conversation.
class PendingExercise {
  const PendingExercise(this.description);

  final String description;
}

/// A running roleplay scene, if one is active.
class RoleplayState {
  const RoleplayState({required this.scenario, this.turnCount = 0});

  final String scenario;
  final int turnCount;
}

/// The arc of the conversation so far: where it started, where it is.
class ConversationArc {
  const ConversationArc({
    required this.turnCount,
    this.openedWith,
    this.currentTopic,
  });

  final int turnCount;
  final String? openedWith;
  final String? currentTopic;
}

/// A compact, honest summary of the conversation — only what happened.
class ConversationSummary {
  const ConversationSummary({
    required this.arc,
    this.topics = const [],
    this.openQuestions = const [],
    this.promises = const [],
    this.pendingExercise,
    this.roleplay,
  });

  final ConversationArc arc;
  final List<ConversationTopic> topics;
  final List<OpenQuestion> openQuestions;
  final List<TeacherPromise> promises;
  final PendingExercise? pendingExercise;
  final RoleplayState? roleplay;

  bool get hasThreads =>
      openQuestions.isNotEmpty ||
      promises.isNotEmpty ||
      pendingExercise != null ||
      roleplay != null;
}

/// The teacher's continuation move: pick up a real thread instead of starting
/// cold. Null thread fields mean there is nothing genuine to resume.
class ConversationContinuation {
  const ConversationContinuation({this.opener, this.thread});

  /// A natural "let's continue" line grounded in the summary.
  final String? opener;

  /// What is being resumed (question / promise / exercise / roleplay / topic).
  final String? thread;
}

final _promisePattern = RegExp(
  r'(next time|la próxima vez|luego veremos|next we|después)',
  caseSensitive: false,
);

/// Extracts the summary from the live transcript — deterministic, transcript
/// only, nothing invented.
ConversationSummary summarizeConversation(ConversationContext context) {
  final turns = context.turns;
  final topics = <String, int>{};
  if (context.topic != null) topics[context.topic!] = 1;

  final promises = <TeacherPromise>[];
  OpenQuestion? open;
  for (var i = 0; i < turns.length; i++) {
    final t = turns[i];
    if (t.fromLearner) continue;
    if (_promisePattern.hasMatch(t.text)) {
      promises.add(TeacherPromise(t.text.trim()));
    }
    // A teacher question is open when no learner turn follows it.
    final isLast = i == turns.length - 1;
    if (isLast && (t.text.contains('?') || t.text.contains('¿'))) {
      open = OpenQuestion(t.text.trim());
    }
  }

  return ConversationSummary(
    arc: ConversationArc(
      turnCount: turns.length,
      openedWith: turns.isEmpty ? null : turns.first.text,
      currentTopic: context.topic,
    ),
    topics: [
      for (final e in topics.entries) ConversationTopic(e.key, mentions: e.value),
    ],
    openQuestions: [?open],
    promises: promises,
    pendingExercise: context.activeExercise == null
        ? null
        : PendingExercise(context.activeExercise!),
    roleplay: context.roleplay == null
        ? null
        : RoleplayState(
            scenario: context.roleplay!,
            turnCount: turns.length,
          ),
  );
}

/// Builds the continuation for the next session/turn from a summary. When no
/// genuine thread exists, both fields are null — the teacher starts fresh
/// rather than pretending to remember.
ConversationContinuation buildContinuation(ConversationSummary summary) {
  if (summary.roleplay != null) {
    return ConversationContinuation(
      opener: 'Seguimos con la escena: ${summary.roleplay!.scenario}.',
      thread: 'roleplay',
    );
  }
  if (summary.pendingExercise != null) {
    return ConversationContinuation(
      opener:
          'We left an exercise unfinished — ${summary.pendingExercise!.description}. '
          "Let's pick it up.",
      thread: 'exercise',
    );
  }
  if (summary.openQuestions.isNotEmpty) {
    return ConversationContinuation(
      opener: 'You never answered me: ${summary.openQuestions.first.question}',
      thread: 'question',
    );
  }
  if (summary.promises.isNotEmpty) {
    return ConversationContinuation(
      opener: 'I promised we would continue — ${summary.promises.first.promise}',
      thread: 'promise',
    );
  }
  if (summary.arc.currentTopic != null) {
    return ConversationContinuation(
      opener:
          'Last time we were talking about ${summary.arc.currentTopic} — '
          "let's continue that conversation.",
      thread: 'topic',
    );
  }
  return const ConversationContinuation();
}
