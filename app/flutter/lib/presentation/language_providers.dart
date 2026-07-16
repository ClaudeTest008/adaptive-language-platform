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
import '../ai/chat_model.dart';
import '../infrastructure/demo_tutor_model.dart';
import '../infrastructure/language_repositories.dart';
import '../language/curriculum.dart';
import '../language/entities.dart';
import '../language/exercises.dart';
import '../language/lesson.dart';
import '../language/misconceptions.dart';
import '../language/signals.dart';
import '../language/tutor.dart';

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
  Future<void>? _initFuture;

  @override
  LanguageLearnerState build() {
    _initFuture = _init();
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

  /// Records one exercise answer on [node]. Returns the misconceptions
  /// detected by THIS answer (empty when correct or unattributed) so
  /// exercise flows can show teacher feedback immediately.
  Future<List<Misconception>> recordAnswer({
    required LanguageNode node,
    required bool correct,
    required double responseSeconds,
    DateTime? at,
  }) async {
    await _initFuture; // answers may arrive before _init completes
    final engine = _engine;
    final detector = _detector;
    if (engine == null || detector == null) return const [];
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

    // Misconception engine over the whole lineage: an error on a child
    // exercise ("Tengo hambre") is evidence of the ancestor grammar
    // concept's misconception (tener-states). Ancestors without authored
    // interference contribute nothing.
    final detected = detector.detect(
      conceptIds: node.lineageConceptIds.reversed.toList(),
      correct: correct,
      at: when,
    );
    final misconceptions = state.misconceptions.record(detected);

    // Signals land on the answered concept plus any ancestor a
    // misconception was attributed to (so its transfer counters move).
    final transferIds = {for (final m in detected) m.conceptId};
    final signals = state.signals.afterAnswer(
      conceptIds: [node.conceptId, ...transferIds.difference({node.conceptId})],
      correct: correct,
      responseSeconds: responseSeconds,
      transferConceptIds: transferIds,
    );

    state = state.copyWith(
      model: model,
      misconceptions: misconceptions,
      signals: signals,
    );
    await ref.read(misconceptionRepositoryProvider).save(misconceptions);
    await ref.read(languageSignalsRepositoryProvider).save(signals);
    return detected;
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

// ---------- practice session (text-first exercise flows, ADR-0017) ----------

class LanguagePracticeState {
  const LanguagePracticeState({
    required this.items,
    required this.index,
    required this.correctCount,
    required this.shownAt,
    this.given,
    this.wasCorrect,
    this.feedback = const [],
    this.finished = false,
  });

  final List<ExerciseItem> items;
  final int index;
  final int correctCount;

  /// When the current exercise appeared — response-time input.
  final DateTime shownAt;

  /// Learner's submission for the current item (null = unanswered).
  final String? given;
  final bool? wasCorrect;

  /// Misconceptions detected by the current answer (teacher feedback).
  final List<Misconception> feedback;
  final bool finished;

  ExerciseItem get current => items[index];
  bool get answered => given != null;

  LanguagePracticeState copyWith({
    int? index,
    int? correctCount,
    String? given,
    bool? wasCorrect,
    List<Misconception>? feedback,
    bool clearAnswer = false,
    bool? finished,
    DateTime? shownAt,
  }) => LanguagePracticeState(
    items: items,
    index: index ?? this.index,
    correctCount: correctCount ?? this.correctCount,
    shownAt: shownAt ?? this.shownAt,
    given: clearAnswer ? null : (given ?? this.given),
    wasCorrect: clearAnswer ? null : (wasCorrect ?? this.wasCorrect),
    feedback: clearAnswer ? const [] : (feedback ?? this.feedback),
    finished: finished ?? this.finished,
  );
}

class LanguagePracticeController extends Notifier<LanguagePracticeState?> {
  @override
  LanguagePracticeState? build() => null;

  /// Starts a session. [focusConceptIds] (repair concepts) sort first.
  void start({List<String> focusConceptIds = const [], int limit = 8}) {
    final curriculum = ref.read(curriculumProvider).value;
    if (curriculum == null) return;
    state = LanguagePracticeState(
      items: generateExercises(
        curriculum.graph,
        focusConceptIds: focusConceptIds,
        limit: limit,
      ),
      index: 0,
      correctCount: 0,
      shownAt: DateTime.now(),
    );
  }

  /// Checks [given], records the real answer event (engine + detector +
  /// signals) and stores teacher feedback for the UI.
  Future<void> submit(String given) async {
    final s = state;
    if (s == null || s.answered || s.finished) return;
    final correct = checkAnswer(s.current, given);
    final detected = await ref
        .read(languageLearnerProvider.notifier)
        .recordAnswer(
          node: s.current.node,
          correct: correct,
          responseSeconds:
              DateTime.now().difference(s.shownAt).inMilliseconds / 1000,
        );
    state = s.copyWith(
      given: given,
      wasCorrect: correct,
      correctCount: s.correctCount + (correct ? 1 : 0),
      feedback: detected,
    );
  }

  void next() {
    final s = state;
    if (s == null || !s.answered) return;
    if (s.index + 1 < s.items.length) {
      state = s.copyWith(
        index: s.index + 1,
        clearAnswer: true,
        shownAt: DateTime.now(),
      );
    } else {
      state = s.copyWith(finished: true);
    }
  }

  void reset() => state = null;
}

final languagePracticeProvider =
    NotifierProvider<LanguagePracticeController, LanguagePracticeState?>(
      LanguagePracticeController.new,
    );

// ---------- AI tutor (Phase 3 foundation, ADR-0018) ----------

/// Vendor swap point: bind AnthropicChatModel/OpenAiChatModel/... here
/// once API keys exist. The demo model consumes the same prompts.
final tutorModelProvider = Provider<AiChatModel>(
  (ref) => const DemoTutorModel(),
);

final languageTutorProvider = Provider<LanguageTutor>(
  (ref) => LanguageTutor(ref.watch(tutorModelProvider)),
);

/// Fresh tutor context from live learner state. [focusConceptId] targets
/// one concept (Teacher/Grammar modes); default focus = the top
/// misconception's concept, so "repair first" is the tutor's opening too.
TutorContext? assembleTutorContext(Ref ref, {String? focusConceptId}) {
  final curriculum = ref.read(curriculumProvider).value;
  if (curriculum == null) return null;
  final learner = ref.read(languageLearnerProvider);
  return buildTutorContext(
    curriculum: curriculum,
    conceptMastery: learner.conceptMastery,
    misconceptions: learner.misconceptions,
    signals: learner.signals,
    goals: const ['Reach A2 Spanish'],
    focusConceptId:
        focusConceptId ?? learner.misconceptions.all.firstOrNull?.conceptId,
  );
}

class TutorSessionState {
  const TutorSessionState({
    required this.mode,
    required this.context,
    this.transcript = const [],
    this.busy = false,
  });

  final TutorMode mode;
  final TutorContext context;

  /// (isTutor, text) pairs, oldest first.
  final List<(bool, String)> transcript;
  final bool busy;

  TutorSessionState copyWith({
    List<(bool, String)>? transcript,
    bool? busy,
  }) => TutorSessionState(
    mode: mode,
    context: context,
    transcript: transcript ?? this.transcript,
    busy: busy ?? this.busy,
  );
}

class TutorSessionController extends Notifier<TutorSessionState?> {
  @override
  TutorSessionState? build() => null;

  /// Starts a session: assembles fresh context and asks the tutor to open.
  Future<void> start(TutorMode mode, {String? focusConceptId}) async {
    final context = assembleTutorContext(ref, focusConceptId: focusConceptId);
    if (context == null) return;
    state = TutorSessionState(mode: mode, context: context, busy: true);
    final reply = await ref.read(languageTutorProvider).respond(
      mode: mode,
      context: context,
      userMessage: 'Start the session.',
    );
    state = state?.copyWith(transcript: [(true, reply.text)], busy: false);
  }

  Future<void> send(String message) async {
    final s = state;
    if (s == null || s.busy || message.trim().isEmpty) return;
    state = s.copyWith(transcript: [...s.transcript, (false, message)], busy: true);
    final history = [
      for (final (isTutor, text) in s.transcript)
        AiMessage(isTutor ? AiRole.assistant : AiRole.user, text),
    ];
    final reply = await ref.read(languageTutorProvider).respond(
      mode: s.mode,
      context: s.context,
      userMessage: message,
      history: history,
    );
    state = state?.copyWith(
      transcript: [...?state?.transcript, (true, reply.text)],
      busy: false,
    );
  }

  void reset() => state = null;
}

final tutorSessionProvider =
    NotifierProvider<TutorSessionController, TutorSessionState?>(
      TutorSessionController.new,
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
