import 'experience.dart';
import 'speaking_session.dart';
import 'teacher_brain.dart';
import 'teacher_events.dart';
import 'teaching_style.dart';

/// Typed Lesson Outcome Engine (Phase 30). Pure, deterministic. Turns a
/// finished lesson into measured evidence: what was practiced, mastered,
/// struggled with, which connections were reinforced, the speaking/reading
/// evidence, and the difficulty experienced. NOTHING is estimated — a field is
/// empty or null when it was not measured. This is the first complete producer
/// for the Teacher Brain's reflections and long-term history.

/// The rich, typed result of one lesson. (Distinct from the brain's compact
/// `LessonOutcome`, which this converts to for `lessonHistory`.)
class LessonResult {
  const LessonResult({
    required this.day,
    required this.objective,
    this.conceptsPracticed = const [],
    this.conceptsMastered = const [],
    this.conceptsStruggled = const [],
    this.connectionsReinforced = const [],
    this.speakingScore,
    this.readingKnownRatio,
    this.difficulty,
    this.observations = const [],
    this.strengths = const [],
    this.weaknesses = const [],
    this.events = const [],
  });

  final String day;
  final String objective;
  final List<String> conceptsPracticed;
  final List<String> conceptsMastered;
  final List<String> conceptsStruggled;
  final List<String> connectionsReinforced;

  /// Mean pronunciation across the lesson's speaking attempts; null if none.
  final double? speakingScore;

  /// Mean known-word ratio across the lesson's reading; null if none.
  final double? readingKnownRatio;

  /// Difficulty the learner experienced (from the pedagogy decision).
  final String? difficulty;
  final List<String> observations;
  final List<String> strengths;
  final List<String> weaknesses;

  /// The typed events this lesson produced.
  final List<TeacherEvent> events;

  bool get isEmpty =>
      conceptsPracticed.isEmpty &&
      speakingScore == null &&
      readingKnownRatio == null;

  /// Compact outcome for the brain's `lessonHistory` — measured only.
  LessonOutcome toOutcome() => LessonOutcome(
    day: day,
    objective: objective,
    score: speakingScore ?? readingKnownRatio ?? 0,
    confidence: speakingScore ?? readingKnownRatio ?? 0,
    mistakes: conceptsStruggled,
    grammarGained: conceptsMastered,
    nextRecommendation: conceptsStruggled.isEmpty
        ? null
        : 'Review: ${conceptsStruggled.first}',
  );
}

double? _mean(Iterable<double> xs) {
  final l = xs.toList();
  return l.isEmpty ? null : double.parse(
    (l.reduce((a, b) => a + b) / l.length).toStringAsFixed(2));
}

/// Builds the lesson result + its events from measured evidence.
LessonResult buildLessonResult({
  required TeacherBrain brain,
  required String day,
  required String objective,
  List<SpeakingSession> speaking = const [],
  List<ReadingRecord> reading = const [],
}) {
  String name(String id) => brain.connections.nodes[id]?.name ?? id.split(':').last;
  double mastery(String id) => brain.connections.nodes[id]?.mastery ?? 0;

  final practiced = <String>{
    for (final s in speaking)
      if (s.conceptId != null) s.conceptId!,
    ...brain.connections.recentlyActivated,
  }.toList();

  final mastered = [for (final id in practiced) if (mastery(id) >= 0.5) name(id)];
  final struggled = <String>{
    for (final s in speaking)
      if (s.conceptId != null && s.pronunciation < 0.6) name(s.conceptId!),
    for (final r in reading)
      if (r.knownRatio < 0.5) r.title,
  }.toList();

  final connections = [
    for (final e in brain.connections.strongConnections.take(3))
      '${name(e.fromId)} ↔ ${name(e.toId)}',
  ];

  final events = <TeacherEvent>[];
  for (final s in speaking) {
    if (s.completed && s.pronunciation >= 0.8) {
      events.add(SpeakingImproved(
        day: day,
        evidence: 'pronunciation ${(s.pronunciation * 100).round()}%',
        conceptIds: s.conceptId == null ? const [] : [s.conceptId!],
        confidence: s.confidence,
      ));
    } else if (!s.completed || s.pronunciation < 0.3) {
      events.add(SpeakingAvoided(
        day: day,
        evidence: s.completed
            ? 'pronunciation ${(s.pronunciation * 100).round()}%'
            : 'no utterance produced',
        conceptIds: s.conceptId == null ? const [] : [s.conceptId!],
      ));
    }
  }
  for (final r in reading) {
    events.add(ReadingCompleted(
      day: day,
      evidence: 'known ratio ${(r.knownRatio * 100).round()}%',
    ));
  }
  if (brain.connections.strongConnections.isNotEmpty) {
    events.add(ConnectionDiscovered(
      day: day,
      evidence: '${brain.connections.strongConnections.length} solid links',
    ));
  }
  events.add(LessonFinished(day: day, evidence: objective));

  return LessonResult(
    day: day,
    objective: objective,
    conceptsPracticed: [for (final id in practiced) name(id)],
    conceptsMastered: mastered,
    conceptsStruggled: struggled,
    connectionsReinforced: connections,
    speakingScore: _mean(speaking.map((s) => s.pronunciation)),
    readingKnownRatio: _mean(reading.map((r) => r.knownRatio)),
    difficulty: brain.pedagogy?.difficulty.name,
    observations: [
      for (final o in brain.notebook.observations.take(2)) o.text,
    ],
    strengths: [
      for (final e in brain.facts.skills.entries)
        if (e.value.trend == Trend.improving) e.key.name,
    ],
    weaknesses: [
      for (final g in brain.facts.grammar)
        if (g.status == GrammarStatus.weak) g.name,
    ].take(3).toList(),
    events: events,
  );
}

/// Produces a real reflection from a lesson result (the reflection model
/// finally has a producer). Measured only — empty fields when nothing to say.
TeacherReflection reflectFromLesson(LessonResult result) {
  final improved = result.events
      .whereType<SpeakingImproved>()
      .map((e) => e.evidence)
      .toList();
  return TeacherReflection(
    day: result.day,
    whatWorked: [
      ...result.conceptsMastered,
      ...result.connectionsReinforced,
    ],
    whatConfused: result.conceptsStruggled,
    whatImproved: improved,
    nextAdjustment: result.difficulty == 'tooDifficult'
        ? 'Slow down and review before introducing anything new.'
        : result.conceptsStruggled.isEmpty
        ? 'Keep building — ready for a small stretch.'
        : 'Reinforce ${result.conceptsStruggled.first} next session.',
  );
}
