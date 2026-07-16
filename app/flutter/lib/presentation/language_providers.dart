/// Riverpod wiring for the language platform layer (ADR-0016).
///
/// The core adaptive engine is reused UNCHANGED: `LearnerEngine` is
/// constructed with the language graph's `toCoreGraph()` projection, so
/// lapse propagation and mastery updates flow through language concept
/// ids exactly as they did through exam topics.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../adaptive/engine.dart';
import '../adaptive/model.dart' as adaptive;
import '../infrastructure/language_repositories.dart';
import '../language/curriculum.dart';
import '../language/entities.dart';
import '../language/lesson.dart';
import '../language/misconceptions.dart';
import '../language/signals.dart';

/// Demo curriculum: Spanish for English speakers (assets/curriculum/).
final curriculumProvider = FutureProvider<Curriculum>((ref) async {
  final raw = await rootBundle.loadString('assets/curriculum/es-for-en.json');
  return parseCurriculum(jsonDecode(raw) as Map<String, dynamic>);
});

final misconceptionRepositoryProvider = Provider<MisconceptionRepository>(
  (ref) => InMemoryMisconceptionRepository(),
);
final languageSignalsRepositoryProvider = Provider<LanguageSignalsRepository>(
  (ref) => InMemoryLanguageSignalsRepository(),
);

class LanguageLearnerState {
  const LanguageLearnerState({
    this.model = const adaptive.LearnerModel(),
    this.misconceptions = const MisconceptionLog(),
    this.signals = const LanguageSignalsStore(),
    this.ready = false,
  });

  /// Core learner model — same type the exam flows use (ADR-0008).
  final adaptive.LearnerModel model;
  final MisconceptionLog misconceptions;
  final LanguageSignalsStore signals;
  final bool ready;

  Map<String, double> get conceptMastery => {
    for (final e in model.concepts.entries) e.key: e.value.mastery,
  };

  LanguageLearnerState copyWith({
    adaptive.LearnerModel? model,
    MisconceptionLog? misconceptions,
    LanguageSignalsStore? signals,
    bool? ready,
  }) => LanguageLearnerState(
    model: model ?? this.model,
    misconceptions: misconceptions ?? this.misconceptions,
    signals: signals ?? this.signals,
    ready: ready ?? this.ready,
  );
}

/// Every language answer event flows through here: core engine update,
/// misconception detection, signal update, persistence.
class LanguageLearnerController extends Notifier<LanguageLearnerState> {
  LearnerEngine? _engine;
  MisconceptionDetector? _detector;

  @override
  LanguageLearnerState build() {
    _init();
    return const LanguageLearnerState();
  }

  Future<void> _init() async {
    final curriculum = await ref.read(curriculumProvider.future);
    _engine = LearnerEngine(graph: curriculum.graph.toCoreGraph());
    _detector = MisconceptionDetector(
      curriculum.graph,
      nativeLanguage: curriculum.nativeLanguage,
    );
    final log = await ref.read(misconceptionRepositoryProvider).load();
    final signals = await ref.read(languageSignalsRepositoryProvider).load();
    state = state.copyWith(misconceptions: log, signals: signals, ready: true);
    if (state.model.totalAnswered == 0) _seedDemo(curriculum);
  }

  /// Records one exercise answer on [node].
  Future<void> recordAnswer({
    required LanguageNode node,
    required bool correct,
    required double responseSeconds,
    DateTime? at,
  }) async {
    final engine = _engine;
    final detector = _detector;
    if (engine == null || detector == null) return;
    final when = at ?? DateTime.now();

    // Core engine: whole lineage exercised, exactly like exam questions.
    // Leaf-first: the AnswerEvent contract is "first = primary concept" —
    // lapse propagation fires from conceptIds.first (engine.dart).
    final model = engine.applyAnswer(
      state.model,
      adaptive.AnswerEvent(
        questionId: 'lx-${node.conceptId}-${when.microsecondsSinceEpoch}',
        conceptIds: node.lineageConceptIds.reversed.toList(),
        correct: correct,
        responseSeconds: responseSeconds,
        difficulty01: 0.5,
        answeredAt: when,
      ),
    );

    // Misconception engine: interference authored on the concept itself.
    final detected = detector.detect(
      conceptIds: [node.conceptId],
      correct: correct,
      at: when,
    );
    final misconceptions = state.misconceptions.record(detected);

    final signals = state.signals.afterAnswer(
      conceptIds: [node.conceptId],
      correct: correct,
      responseSeconds: responseSeconds,
      transferConceptIds: {for (final m in detected) m.conceptId},
    );

    state = state.copyWith(
      model: model,
      misconceptions: misconceptions,
      signals: signals,
    );
    await ref.read(misconceptionRepositoryProvider).save(misconceptions);
    await ref.read(languageSignalsRepositoryProvider).save(signals);
  }

  /// Deterministic demo learner (ADR-0006 demo mode): strong vocabulary,
  /// weak grammar with two live misconceptions — the showcase state the
  /// Phase 2 screens render.
  void _seedDemo(Curriculum c) {
    final g = c.graph;
    var t = DateTime(2026, 7, 15, 9);
    Future<void> answer(String id, bool correct, double seconds) {
      final node = g[id];
      if (node == null) return Future.value();
      t = t.add(const Duration(minutes: 3));
      return recordAnswer(
        node: node,
        correct: correct,
        responseSeconds: seconds,
        at: t,
      );
    }

    const vocabFruit = 'es:a1:vocabulary:food:fruit:manzana';
    const vocabFalse = 'es:a1:vocabulary:food:restaurant:embarazada';
    const arVerbs = 'es:a1:grammar:verbs:present-tense:ar-verbs';
    const tener = 'es:a1:grammar:verbs:states:tener-states';
    const serEstar = 'es:a1:grammar:verbs:states:ser-estar';
    const ordering = 'es:a1:conversation:ordering-food';
    const mealTimes = 'es:a1:culture:meal-times';

    // Vocabulary: fast and solid, one false-friend slip.
    answer(vocabFruit, true, 2.1);
    answer(vocabFruit, true, 1.6);
    answer(vocabFruit, true, 1.2);
    answer(vocabFalse, false, 6.8); // false friend bites
    answer(vocabFalse, true, 3.0);

    // Grammar: -ar verbs fine; tener-states hit twice (transfer error),
    // ser/estar once — the misconception showcase.
    answer(arVerbs, true, 4.0);
    answer(arVerbs, true, 3.2);
    answer(tener, false, 8.5);
    answer(tener, false, 7.9);
    answer(serEstar, false, 9.1);
    answer(serEstar, true, 5.0);

    // A taste of conversation + culture.
    answer(ordering, true, 12.0);
    answer(mealTimes, true, 4.5);
  }
}

final languageLearnerProvider =
    NotifierProvider<LanguageLearnerController, LanguageLearnerState>(
      LanguageLearnerController.new,
    );

/// Per-skill mastery for the dashboard (Spanish: Vocabulary 85% …).
final languageSkillMasteryProvider = Provider<Map<LanguageSkill, double>>((
  ref,
) {
  final st = ref.watch(languageLearnerProvider);
  final curriculum = ref.watch(curriculumProvider).value;
  if (curriculum == null) return const {};
  return skillMastery(st.conceptMastery, curriculum.graph);
});

/// Today's lesson preview, misconception repair first.
final lessonPreviewProvider = Provider<List<LessonBlock>>((ref) {
  final st = ref.watch(languageLearnerProvider);
  final curriculum = ref.watch(curriculumProvider).value;
  if (curriculum == null) return const [];
  return previewDailyLesson(
    conceptMastery: st.conceptMastery,
    graph: curriculum.graph,
    misconceptions: st.misconceptions,
  );
});
