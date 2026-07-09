/// LearnerModel JSON codec (ADR-0009): the serialization contract for the
/// Firestore `learnerModel` documents (docs/database/04-adaptive-schema.md).
/// Pure Dart; the Firestore repository maps these maps 1:1 to documents,
/// so persistence lands as infrastructure wiring only.
library;

import 'model.dart';

Map<String, dynamic> conceptStatsToJson(ConceptStats s) => {
  'conceptId': s.conceptId,
  'attempts': s.attempts,
  'correct': s.correct,
  'streak': s.streak,
  'lapses': s.lapses,
  'mastery': s.mastery,
  'avgResponseSeconds': s.avgResponseSeconds,
  'intervalDays': s.intervalDays,
  if (s.lastAnsweredAt != null)
    'lastAnsweredAt': s.lastAnsweredAt!.toIso8601String(),
  if (s.nextReviewAt != null) 'nextReviewAt': s.nextReviewAt!.toIso8601String(),
};

ConceptStats conceptStatsFromJson(Map<String, dynamic> j) => ConceptStats(
  conceptId: j['conceptId'] as String,
  attempts: (j['attempts'] as num?)?.toInt() ?? 0,
  correct: (j['correct'] as num?)?.toInt() ?? 0,
  streak: (j['streak'] as num?)?.toInt() ?? 0,
  lapses: (j['lapses'] as num?)?.toInt() ?? 0,
  mastery: (j['mastery'] as num?)?.toDouble() ?? 0,
  avgResponseSeconds: (j['avgResponseSeconds'] as num?)?.toDouble() ?? 0,
  intervalDays: (j['intervalDays'] as num?)?.toDouble() ?? 0,
  lastAnsweredAt: j['lastAnsweredAt'] != null
      ? DateTime.tryParse(j['lastAnsweredAt'] as String)
      : null,
  nextReviewAt: j['nextReviewAt'] != null
      ? DateTime.tryParse(j['nextReviewAt'] as String)
      : null,
);

Map<String, dynamic> learnerModelToJson(LearnerModel m) => {
  'totalAnswered': m.totalAnswered,
  'totalCorrect': m.totalCorrect,
  'mockExamScores': m.mockExamScores,
  'studyDays': m.studyDays.toList(),
  'concepts': {
    for (final e in m.concepts.entries) e.key: conceptStatsToJson(e.value),
  },
};

LearnerModel learnerModelFromJson(Map<String, dynamic> j) => LearnerModel(
  totalAnswered: (j['totalAnswered'] as num?)?.toInt() ?? 0,
  totalCorrect: (j['totalCorrect'] as num?)?.toInt() ?? 0,
  mockExamScores: [
    for (final s in (j['mockExamScores'] as List?) ?? const [])
      (s as num).toDouble(),
  ],
  studyDays: {
    for (final d in (j['studyDays'] as List?) ?? const []) d as String,
  },
  concepts: {
    for (final e in ((j['concepts'] as Map?) ?? const {}).entries)
      e.key as String: conceptStatsFromJson(
        (e.value as Map).cast<String, dynamic>(),
      ),
  },
);
