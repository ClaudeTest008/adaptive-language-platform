import 'connections.dart';
import 'speaking.dart';
import 'teacher_brain.dart';

/// Speaking analytics (Phase 23). Turns a recognized utterance — from local
/// Whisper or the platform recognizer, the source does not matter — into
/// first-class learning evidence: a measured [SpeakingSession] the Teacher
/// Brain derives outcomes from. Pure, deterministic, offline. Every number is
/// measured from the transcript/timing; unmeasured values stay null.

/// Common Spanish/English hesitation fillers — used to count disfluency.
const _fillers = {
  'eh', 'em', 'este', 'esto', 'pues', 'o', 'sea', 'um', 'uh', 'like', 'well',
  'mmm', 'mm', 'ehh', 'ah',
};

/// One completed speaking attempt, fully measured.
class SpeakingSession {
  const SpeakingSession({
    required this.target,
    required this.transcript,
    required this.pronunciation,
    required this.repairAttempts,
    required this.completed,
    this.fluency,
    this.hesitationCount = 0,
    this.fillerCount = 0,
    this.confidence,
    this.conceptId,
  });

  final String target;
  final String transcript;

  /// 0…1 pronunciation score (phoneme-aware).
  final double pronunciation;

  /// Retries before this attempt landed.
  final int repairAttempts;

  /// The learner produced a non-empty utterance.
  final bool completed;

  /// Words per second vs an expected pace; null when duration is unknown.
  final double? fluency;
  final int hesitationCount;
  final int fillerCount;

  /// Behavioural confidence (0…1): high pronunciation + low hesitation + few
  /// repairs. Null when the learner said nothing.
  final double? confidence;
  final String? conceptId;
}

int _wordCount(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

/// Analyzes one spoken attempt against [target]. [durationMs] enables fluency;
/// [retries] is how many attempts preceded this one.
SpeakingSession analyzeSpeaking(
  String target,
  String transcript, {
  int? durationMs,
  int retries = 0,
  String? conceptId,
}) {
  final pron = scorePronunciation(target, transcript);
  final words = transcript.toLowerCase().split(RegExp(r'[^a-záéíóúüñ]+'))
    ..removeWhere((w) => w.isEmpty);
  final fillerCount = words.where(_fillers.contains).length;
  // Hesitation: repeated adjacent words ("yo yo tengo") + fillers.
  var repeats = 0;
  for (var i = 1; i < words.length; i++) {
    if (words[i] == words[i - 1]) repeats++;
  }
  final hesitation = fillerCount + repeats;
  final completed = _wordCount(transcript) > 0;

  double? fluency;
  if (durationMs != null && durationMs > 0 && completed) {
    final wps = _wordCount(transcript) / (durationMs / 1000);
    // ~2 words/sec is a comfortable learner pace → 1.0; clamp.
    fluency = double.parse((wps / 2.0).clamp(0.0, 1.0).toStringAsFixed(2));
  }

  double? confidence;
  if (completed) {
    final penalty = (hesitation * 0.08) + (retries * 0.1);
    confidence = double.parse(
      (pron - penalty).clamp(0.0, 1.0).toStringAsFixed(2),
    );
  }

  return SpeakingSession(
    target: target,
    transcript: transcript,
    pronunciation: double.parse(pron.toStringAsFixed(2)),
    repairAttempts: retries,
    completed: completed,
    fluency: fluency,
    hesitationCount: hesitation,
    fillerCount: fillerCount,
    confidence: confidence,
    conceptId: conceptId,
  );
}

/// Derives a lesson outcome for the Teacher Brain from a speaking session.
LessonOutcome speakingOutcome(SpeakingSession s, String day) => LessonOutcome(
  day: day,
  objective: 'Said "${s.target}"',
  score: s.pronunciation,
  confidence: s.confidence ?? s.pronunciation,
  mistakes: [
    if (!s.completed) 'no utterance produced',
    if (s.hesitationCount >= 3) 'hesitant delivery',
  ],
  nextRecommendation: s.pronunciation < 0.6
      ? 'Drill: ${s.target}'
      : null,
);

/// Connection-based spoken feedback (Phase 23): when the learner's utterance
/// belongs to a family the brain tracks, praise it by naming the family — so
/// speaking reinforces the mental network instead of an isolated "Correct."
/// Returns null when there is no connection to draw (caller falls back to a
/// plain acknowledgement — never fabricate a link).
String? connectionFeedback(SpeakingSession s, TeacherBrain brain) {
  if (!s.completed || s.pronunciation < 0.6 || s.conceptId == null) return null;
  final domain = domainAncestor(s.conceptId!);
  final family = <String>[];
  for (final c in brain.connections.clusters) {
    if (c.id != domain) continue;
    for (final id in c.memberIds) {
      final name = brain.connections.nodes[id]?.name;
      if (name != null && !family.contains(name)) family.add(name);
    }
  }
  if (family.length < 2) return null;
  final list = family.take(4).join(', ');
  return 'Excellent. You used the same pattern as $list — '
      "you're starting to think in the language, not translate it.";
}
