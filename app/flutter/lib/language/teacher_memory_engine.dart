import 'teacher_brain.dart';
import 'teacher_memory.dart';

/// Long-Term Memory Engine (Phase 31). Pure, deterministic. Turns the persisted
/// teaching history into a longitudinal picture: what the learner has achieved,
/// where they are strong or weak over time, which misconceptions and
/// connections recur, which skills recovered or are fading, and the momentum of
/// learning and teaching. Everything is DERIVED from measured completed
/// lessons — nothing estimated; empty/neutral when there is no history.

enum MemoryTrend { improving, steady, declining, unknown }

class TeacherMemorySummary {
  const TeacherMemorySummary({
    this.recentAchievements = const [],
    this.longTermStrengths = const [],
    this.longTermWeaknesses = const [],
    this.recurringMisconceptions = const [],
    this.recurringConnections = const [],
    this.recoveredSkills = const [],
    this.forgottenSkills = const [],
    this.confidenceTrend = MemoryTrend.unknown,
    this.motivationTrend = MemoryTrend.unknown,
    this.learningMomentum = 0,
    this.teachingMomentum = 0,
    this.lessonsCompleted = 0,
  });

  final List<String> recentAchievements;
  final List<String> longTermStrengths;
  final List<String> longTermWeaknesses;
  final List<String> recurringMisconceptions;
  final List<String> recurringConnections;

  /// Concepts once struggled with, later mastered.
  final List<String> recoveredSkills;

  /// Concepts mastered long ago, not practiced recently and never strongly
  /// held — candidates to "reconnect" (never "you forgot").
  final List<String> forgottenSkills;
  final MemoryTrend confidenceTrend;
  final MemoryTrend motivationTrend;

  /// Recent-vs-earlier score delta (-1…1).
  final double learningMomentum;

  /// Consistency of recent lessons (0…1).
  final double teachingMomentum;
  final int lessonsCompleted;

  bool get isEmpty => lessonsCompleted == 0;
}

int _daysBetween(String from, String to) {
  try {
    return DateTime.parse(to).difference(DateTime.parse(from)).inDays;
  } catch (_) {
    return 0;
  }
}

List<String> _recurring(List<List<String>> lists, {int min = 2, int max = 5}) {
  final counts = <String, int>{};
  for (final l in lists) {
    for (final s in l.toSet()) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
  }
  final ranked = counts.entries.where((e) => e.value >= min).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(max)) e.key];
}

MemoryTrend _trend(List<double> series) {
  if (series.length < 2) return MemoryTrend.unknown;
  final half = series.length ~/ 2;
  final earlier = series.sublist(0, half);
  final later = series.sublist(half);
  double avg(List<double> x) => x.reduce((a, b) => a + b) / x.length;
  final delta = avg(later) - avg(earlier);
  if (delta > 0.03) return MemoryTrend.improving;
  if (delta < -0.03) return MemoryTrend.declining;
  return MemoryTrend.steady;
}

/// The concepts that have decayed: mastered in the past, not practiced within
/// [halfLifeDays], and never strongly/repeatedly held. Deterministic — no
/// randomness. Strongly-mastered concepts (mastered in many lessons) are
/// stable and never decay.
List<String> decayedConcepts(
  List<CompletedLesson> lessons, {
  required String today,
  int halfLifeDays = 14,
}) {
  final lastMastered = <String, String>{};
  final masteryCount = <String, int>{};
  for (final l in lessons) {
    for (final c in l.conceptsMastered) {
      masteryCount[c] = (masteryCount[c] ?? 0) + 1;
      final prev = lastMastered[c];
      if (prev == null || l.day.compareTo(prev) > 0) lastMastered[c] = l.day;
    }
  }
  final decayed = <String>[];
  for (final e in lastMastered.entries) {
    final daysSince = _daysBetween(e.value, today);
    final strong = (masteryCount[e.key] ?? 0) >= 3;
    if (!strong && daysSince > halfLifeDays) decayed.add(e.key);
  }
  return decayed;
}

/// Builds the longitudinal summary from persisted lessons + the current brain.
TeacherMemorySummary summarizeMemory({
  required TeacherBrain brain,
  required List<CompletedLesson> lessons,
  required String today,
}) {
  if (lessons.isEmpty) {
    return TeacherMemorySummary(
      motivationTrend: switch (brain.profile.motivation.state.name) {
        'flowing' => MemoryTrend.improving,
        'strained' => MemoryTrend.declining,
        _ => MemoryTrend.unknown,
      },
    );
  }

  final ordered = [...lessons]..sort((a, b) => a.day.compareTo(b.day));
  final masteredLists = [for (final l in ordered) l.conceptsMastered];
  final struggledLists = [for (final l in ordered) l.conceptsStruggled];

  // Recovered: struggled in an earlier lesson, mastered in a later one.
  final recovered = <String>[];
  for (var i = 0; i < ordered.length; i++) {
    for (final c in ordered[i].conceptsStruggled) {
      final later = ordered
          .sublist(i + 1)
          .any((l) => l.conceptsMastered.contains(c));
      if (later && !recovered.contains(c)) recovered.add(c);
    }
  }

  final scores = [for (final l in ordered) l.score];
  final recent = ordered.length <= 5
      ? ordered
      : ordered.sublist(ordered.length - 5);
  final achievements = <String>[
    for (final l in recent.reversed)
      ...l.conceptsMastered,
    for (final l in recent.reversed) ...l.reflectionImproved,
  ];

  // Learning momentum: recent avg score − earlier avg.
  double avg(List<double> x) =>
      x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;
  final half = scores.length ~/ 2;
  final momentum = scores.length < 2
      ? 0.0
      : double.parse(
          (avg(scores.sublist(half)) - avg(scores.sublist(0, half)))
              .clamp(-1.0, 1.0)
              .toStringAsFixed(2));

  // Teaching momentum: lessons within the last ~14 days / a light cap.
  final recentDays = ordered
      .where((l) => _daysBetween(l.day, today) <= 14)
      .length;
  final teaching = double.parse((recentDays / 7).clamp(0.0, 1.0)
      .toStringAsFixed(2));

  return TeacherMemorySummary(
    lessonsCompleted: ordered.length,
    recentAchievements: achievements.toSet().take(5).toList(),
    longTermStrengths: _recurring(masteredLists),
    longTermWeaknesses: _recurring(struggledLists),
    recurringMisconceptions: _recurring(struggledLists, min: 2),
    recurringConnections:
        _recurring([for (final l in ordered) l.connectionsReinforced]),
    recoveredSkills: recovered.take(5).toList(),
    forgottenSkills: decayedConcepts(ordered, today: today),
    confidenceTrend: _trend(scores),
    motivationTrend: switch (brain.profile.motivation.state.name) {
      'flowing' => MemoryTrend.improving,
      'strained' => MemoryTrend.declining,
      _ => _trend(scores),
    },
    learningMomentum: momentum,
    teachingMomentum: teaching,
  );
}
