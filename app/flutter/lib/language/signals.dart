/// Language memory signals (ADR-0015). Pure value types + aggregation.
///
/// These are the language-specific signals the vision's Memory System
/// tracks per concept. Phase 1 defines the contract; Phase 2 wires them
/// into answer-event flows. The Adaptive Learning Core's LearnerModel is
/// NOT modified — signals live beside it, keyed by the same concept ids.
library;

import 'entities.dart';
import 'relationships.dart';

/// Per-concept language signals, all additive to core mastery.
class LanguageConceptSignals {
  const LanguageConceptSignals({
    this.recallDifficulty = 0.5,
    this.recallSpeedMs,
    this.pronunciationConfidence,
    this.listeningRecognition,
    this.conversationAbility,
    this.grammarTransferErrors = 0,
    this.usageFrequency = 0,
    this.nativeInterference = 0,
  });

  /// 0 (instant recall) … 1 (cannot recall). Drives review priority.
  final double recallDifficulty;

  /// Median response time; null until measured.
  final int? recallSpeedMs;

  /// 0…1; null until a pronunciation exercise produced a score (Phase 6).
  final double? pronunciationConfidence;

  /// 0…1; null until listening exercises exist (Phase 5/6).
  final double? listeningRecognition;

  /// 0…1; null until the conversation engine produces scores (Phase 5).
  final double? conversationAbility;

  /// Count of errors attributed to native-language grammar transfer
  /// (misconception engine, Phase 2).
  final int grammarTransferErrors;

  /// How often the learner has actively used the concept (production,
  /// not just recognition).
  final int usageFrequency;

  /// 0…1 estimate of interference pressure from the native language,
  /// seeded from interferesWith/falseFriend relations, updated by errors.
  final double nativeInterference;

  LanguageConceptSignals copyWith({
    double? recallDifficulty,
    int? recallSpeedMs,
    double? pronunciationConfidence,
    double? listeningRecognition,
    double? conversationAbility,
    int? grammarTransferErrors,
    int? usageFrequency,
    double? nativeInterference,
  }) => LanguageConceptSignals(
    recallDifficulty: recallDifficulty ?? this.recallDifficulty,
    recallSpeedMs: recallSpeedMs ?? this.recallSpeedMs,
    pronunciationConfidence:
        pronunciationConfidence ?? this.pronunciationConfidence,
    listeningRecognition: listeningRecognition ?? this.listeningRecognition,
    conversationAbility: conversationAbility ?? this.conversationAbility,
    grammarTransferErrors:
        grammarTransferErrors ?? this.grammarTransferErrors,
    usageFrequency: usageFrequency ?? this.usageFrequency,
    nativeInterference: nativeInterference ?? this.nativeInterference,
  );

  /// Applies one answer event. EWMA (alpha [_alpha]) so recent evidence
  /// dominates without erasing history — same philosophy as the core
  /// engine's mastery update, but the core model is never modified.
  ///
  /// [transferError] = the misconception detector attributed this error
  /// to native-language interference.
  LanguageConceptSignals afterAnswer({
    required bool correct,
    required double responseSeconds,
    bool transferError = false,
  }) {
    const alpha = 0.3;
    final ms = (responseSeconds * 1000).round();
    return copyWith(
      recallDifficulty:
          recallDifficulty * (1 - alpha) + (correct ? 0.0 : 1.0) * alpha,
      recallSpeedMs: recallSpeedMs == null
          ? ms
          : (recallSpeedMs! * (1 - alpha) + ms * alpha).round(),
      usageFrequency: usageFrequency + 1,
      grammarTransferErrors: grammarTransferErrors + (transferError ? 1 : 0),
      nativeInterference: transferError
          ? nativeInterference * (1 - alpha) + alpha
          : nativeInterference * (1 - alpha),
    );
  }
}

/// Per-learner signal state: concept id → signals. Immutable.
class LanguageSignalsStore {
  const LanguageSignalsStore([this.byConcept = const {}]);

  final Map<String, LanguageConceptSignals> byConcept;

  LanguageConceptSignals operator [](String conceptId) =>
      byConcept[conceptId] ?? const LanguageConceptSignals();

  /// Applies one answer to every concept it exercises. [transferConceptIds]
  /// are the concepts the misconception detector flagged on this answer.
  LanguageSignalsStore afterAnswer({
    required List<String> conceptIds,
    required bool correct,
    required double responseSeconds,
    Set<String> transferConceptIds = const {},
  }) {
    final next = Map<String, LanguageConceptSignals>.of(byConcept);
    for (final id in conceptIds) {
      next[id] = this[id].afterAnswer(
        correct: correct,
        responseSeconds: responseSeconds,
        transferError: transferConceptIds.contains(id),
      );
    }
    return LanguageSignalsStore(next);
  }
}

/// Persistence seam (ADR-0015 consequence: contracts land with their
/// first producer). In-memory demo implementation until the Firestore
/// swap (`docs/database/05-language-schema.md`, Phase 8).
abstract class LanguageSignalsRepository {
  Future<LanguageSignalsStore> load();
  Future<void> save(LanguageSignalsStore store);
}

/// Independent mastery per skill, aggregated from per-concept mastery.
///
/// [conceptMastery] is the core LearnerModel's mastery map (concept id →
/// 0…1) — consumed read-only, keyed by the shared concept ids. A concept
/// counts toward the nearest skill on its lineage; concepts above the
/// skill tier are ignored.
Map<LanguageSkill, double> skillMastery(
  Map<String, double> conceptMastery,
  LanguageKnowledgeGraph graph,
) {
  final sums = <LanguageSkill, double>{};
  final counts = <LanguageSkill, int>{};
  for (final e in conceptMastery.entries) {
    final skill = graph[e.key]?.skill;
    if (skill == null) continue;
    sums[skill] = (sums[skill] ?? 0) + e.value;
    counts[skill] = (counts[skill] ?? 0) + 1;
  }
  return {for (final s in sums.keys) s: sums[s]! / counts[s]!};
}

/// Weakest skills first — daily lesson engine input (Phase 4).
List<LanguageSkill> weakestSkills(
  Map<String, double> conceptMastery,
  LanguageKnowledgeGraph graph,
) {
  final mastery = skillMastery(conceptMastery, graph);
  final ranked = mastery.keys.toList()
    ..sort((a, b) => mastery[a]!.compareTo(mastery[b]!));
  return ranked;
}
