// ignore_for_file: dangling_library_doc_comments
/// Typed Teacher Events (Phase 30). Pure, deterministic. The first time
/// teaching itself becomes data: every meaningful thing that happens in a
/// lesson is a typed event — never a loose string — carrying the day it
/// happened, the concepts it touched, the measured evidence behind it, its
/// source, and (when known) a confidence. Events are DERIVED from measured
/// evidence (speaking/reading/brain deltas); nothing is invented.
///
/// These feed lesson outcomes, reflections and the Teacher Brain's history —
/// they are not a new learner store.

/// Where an event was observed.
enum EventSource { speaking, reading, practice, tutor, roleplay, brain }

/// The typed event kinds (for serialization + exhaustive handling).
enum TeacherEventKind {
  conceptLearned,
  conceptForgotten,
  misconceptionDetected,
  misconceptionResolved,
  speakingAvoided,
  speakingImproved,
  confidenceRecovered,
  connectionDiscovered,
  mentalModelUnderstood,
  readingCompleted,
  roleplayCompleted,
  lessonFinished,
  conversationContinued,
  questionAnswered,
  questionSkipped,
}

/// Base typed event. Subclasses are exhaustive over [TeacherEventKind].
sealed class TeacherEvent {
  const TeacherEvent({
    required this.day,
    required this.evidence,
    required this.source,
    this.conceptIds = const [],
    this.confidence,
  });

  final String day;

  /// One measured fact justifying the event (e.g. "pronunciation 0.82").
  final String evidence;
  final EventSource source;
  final List<String> conceptIds;
  final double? confidence;

  TeacherEventKind get kind;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'day': day,
    'evidence': evidence,
    'source': source.name,
    'conceptIds': conceptIds,
    'confidence': confidence,
  };
}

class ConceptLearned extends TeacherEvent {
  const ConceptLearned({
    required super.day,
    required super.evidence,
    required super.source,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.conceptLearned;
}

class ConceptForgotten extends TeacherEvent {
  const ConceptForgotten({
    required super.day,
    required super.evidence,
    required super.source,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.conceptForgotten;
}

class MisconceptionDetected extends TeacherEvent {
  const MisconceptionDetected({
    required super.day,
    required super.evidence,
    required super.source,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.misconceptionDetected;
}

class MisconceptionResolved extends TeacherEvent {
  const MisconceptionResolved({
    required super.day,
    required super.evidence,
    required super.source,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.misconceptionResolved;
}

class SpeakingAvoided extends TeacherEvent {
  const SpeakingAvoided({
    required super.day,
    required super.evidence,
    super.source = EventSource.speaking,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.speakingAvoided;
}

class SpeakingImproved extends TeacherEvent {
  const SpeakingImproved({
    required super.day,
    required super.evidence,
    super.source = EventSource.speaking,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.speakingImproved;
}

class ConfidenceRecovered extends TeacherEvent {
  const ConfidenceRecovered({
    required super.day,
    required super.evidence,
    super.source = EventSource.brain,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.confidenceRecovered;
}

class ConnectionDiscovered extends TeacherEvent {
  const ConnectionDiscovered({
    required super.day,
    required super.evidence,
    super.source = EventSource.brain,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.connectionDiscovered;
}

class MentalModelUnderstood extends TeacherEvent {
  const MentalModelUnderstood({
    required super.day,
    required super.evidence,
    super.source = EventSource.brain,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.mentalModelUnderstood;
}

class ReadingCompleted extends TeacherEvent {
  const ReadingCompleted({
    required super.day,
    required super.evidence,
    super.source = EventSource.reading,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.readingCompleted;
}

class RoleplayCompleted extends TeacherEvent {
  const RoleplayCompleted({
    required super.day,
    required super.evidence,
    super.source = EventSource.roleplay,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.roleplayCompleted;
}

class LessonFinished extends TeacherEvent {
  const LessonFinished({
    required super.day,
    required super.evidence,
    super.source = EventSource.tutor,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.lessonFinished;
}

class ConversationContinued extends TeacherEvent {
  const ConversationContinued({
    required super.day,
    required super.evidence,
    super.source = EventSource.tutor,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.conversationContinued;
}

class QuestionAnswered extends TeacherEvent {
  const QuestionAnswered({
    required super.day,
    required super.evidence,
    super.source = EventSource.tutor,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.questionAnswered;
}

class QuestionSkipped extends TeacherEvent {
  const QuestionSkipped({
    required super.day,
    required super.evidence,
    super.source = EventSource.tutor,
    super.conceptIds,
    super.confidence,
  });
  @override
  TeacherEventKind get kind => TeacherEventKind.questionSkipped;
}
