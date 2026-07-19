/// Riverpod wiring for the language platform layer (ADR-0016).
///
/// The core adaptive engine is reused UNCHANGED: `LearnerEngine` is
/// constructed with the language graph's `toCoreGraph()` projection, so
/// lapse propagation and mastery updates flow through language concept
/// ids exactly as they did through exam topics.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'dart:convert';

import '../adaptive/engine.dart';
import '../adaptive/model.dart' as adaptive;
import '../ai/chat_model.dart';
import '../infrastructure/demo_tutor_model.dart';
import '../infrastructure/language_content_repository.dart';
import '../infrastructure/language_repositories.dart';
import '../infrastructure/piper_speech_service.dart';
import '../infrastructure/platform_speech_service.dart';
import '../infrastructure/prefs_experience_repository.dart';
import '../infrastructure/prefs_notebook_repository.dart';
import '../language/book_analytics.dart';
import '../language/book_ingestion.dart';
import '../language/experience.dart';
import '../language/conversation.dart';
import '../language/content_merge.dart';
import '../language/curriculum.dart';
import '../language/entities.dart';
import '../language/exercises.dart';
import '../language/ingestion.dart';
import '../language/lesson.dart';
import '../language/lesson_generator.dart';
import '../language/misconceptions.dart';
import '../language/notebook.dart';
import '../language/notebook_repository.dart';
import '../language/pipeline.dart';
import '../language/reasoning_engine.dart';
import '../language/local_llm/llm_model_manager.dart';
import '../language/local_llm/llm_pipeline.dart';
import '../language/local_llm/llm_repository.dart';
import '../language/local_llm/local_llm.dart';
import '../infrastructure/prefs_teacher_memory_repository.dart';
import '../language/conversation_continuity.dart';
import '../language/lesson_outcomes.dart';
import '../language/roleplay_engine.dart';
import '../language/connection_optimization.dart';
import '../language/learning_journey_engine.dart';
import '../language/reader_intelligence.dart';
import '../language/reading_analytics.dart';
import '../language/recommendation_engine.dart';
import '../language/vocabulary_growth.dart';
import '../language/teacher_memory.dart';
import '../language/teacher_memory_engine.dart';
import '../language/speaking_session.dart';
import '../language/teacher_intelligence.dart';
import '../infrastructure/llm_downloader.dart';
import '../language/whisper/whisper_model_manager.dart';
import '../language/whisper/whisper_pipeline.dart';
import '../language/whisper/whisper_repository.dart';
import '../language/whisper/whisper_service.dart';
import '../infrastructure/whisper_downloader.dart';
import '../language/signals.dart';
import '../language/teacher_brain.dart';
import '../language/speaking.dart';
import '../language/speech.dart';
import '../language/story.dart';
import '../language/teaching_planner.dart';
import '../language/tutor.dart';

/// Available (target language, native language) curricula. Adding a
/// language = adding a curriculum + stories JSON and one row here.
/// `bcp47` is the target-language voice tag for text-to-speech.
const availableLanguages = [
  (
    code: 'es', name: 'Spanish', flag: '🇪🇸', bcp47: 'es-ES',
    asset: 'assets/curriculum/es-for-en.json',
    stories: 'assets/stories/es-for-en.json',
  ),
  (
    code: 'en', name: 'English', flag: '🇬🇧', bcp47: 'en-US',
    asset: 'assets/curriculum/en-for-es.json',
    stories: 'assets/stories/en-for-es.json',
  ),
];

/// Currently selected target language (Language Lab selector).
final selectedLanguageProvider = StateProvider<String>((ref) => 'es');

/// BCP-47 voice tag for the selected language (TTS/STT).
final languageBcp47Provider = Provider<String>((ref) {
  final code = ref.watch(selectedLanguageProvider);
  return availableLanguages.firstWhere((l) => l.code == code).bcp47;
});

/// Approved Content-Studio candidates for the selected language (ADR-0026).
/// Resets on language switch; the Content Studio appends to it on approve.
class ApprovedContentController extends Notifier<List<ContentCandidate>> {
  @override
  List<ContentCandidate> build() {
    ref.watch(selectedLanguageProvider);
    return const [];
  }

  void add(ContentCandidate c) {
    if (state.any((e) => e.id == c.id)) return;
    state = [...state, c];
  }

  void remove(String id) => state = [for (final c in state) if (c.id != id) c];
}

final approvedContentProvider =
    NotifierProvider<ApprovedContentController, List<ContentCandidate>>(
      ApprovedContentController.new,
    );

final curriculumProvider = FutureProvider<Curriculum>((ref) async {
  final code = ref.watch(selectedLanguageProvider);
  final lang = availableLanguages.firstWhere((l) => l.code == code);
  final raw = await rootBundle.loadString(lang.asset);
  final base = parseCurriculum(jsonDecode(raw) as Map<String, dynamic>);
  // Fold in approved ingested content (ADR-0026).
  return mergeApprovedContent(base, ref.watch(approvedContentProvider));
});

/// Stories for the selected language, capped at the learner's goal level,
/// plus any story synthesized from approved ingested sentences.
final storiesProvider = FutureProvider<List<Story>>((ref) async {
  final code = ref.watch(selectedLanguageProvider);
  final lang = availableLanguages.firstWhere((l) => l.code == code);
  final raw = await rootBundle.loadString(lang.stories);
  final all = [...parseStories(jsonDecode(raw) as Map<String, dynamic>)];
  // Flagship multi-chapter novels live in their own asset per language.
  if (code == 'es') {
    final novelRaw =
        await rootBundle.loadString('assets/stories/es-novela-faro.json');
    all.addAll(parseStories(jsonDecode(novelRaw) as Map<String, dynamic>));
  }
  final ingested = storyFromApproved(
    ref.watch(approvedContentProvider),
    languageCode: code,
    level: CefrLevel.a1,
  );
  if (ingested != null) all.insert(0, ingested);
  // Phase 22: learner-imported books join the shelf (already level-agnostic).
  all.addAll(await ref.watch(importedBooksProvider.future));
  final target = ref.watch(learnerGoalsProvider).targetLevel;
  return storiesForLevel(all, target);
});

/// Voice settings (session-persistent, like themeMode). Engine choice —
/// Piper (offline neural, default) with the platform engine as fallback —
/// and a playback-speed multiplier the learner sets in Voice Settings.
final speechEngineProvider =
    StateProvider<SpeechEngine>((ref) => SpeechEngine.piper);
final speechSpeedProvider = StateProvider<double>((ref) => 1.0);

/// Singletons: Piper holds a downloaded model + engines, the platform
/// service holds STT state — both must survive engine switches.
final platformSpeechProvider = Provider<PlatformSpeechService>(
  (ref) => PlatformSpeechService(),
);
final piperSpeechProvider = Provider<PiperSpeechService>(
  (ref) => PiperSpeechService(ref.watch(platformSpeechProvider)),
);

/// Speech (TTS/STT). The concrete engine is chosen behind this seam, so the
/// UI never depends on it: Piper (real offline-neural synthesis via
/// sherpa_onnx; model downloaded on first use) or the device TTS. A
/// NoopSpeechService is bound in tests.
final speechServiceProvider = Provider<SpeechService>((ref) {
  final engine = ref.watch(speechEngineProvider);
  return switch (engine) {
    SpeechEngine.piper => ref.watch(piperSpeechProvider),
    _ => ref.watch(platformSpeechProvider),
  };
});

// ---------- content ingestion (ADR-0025) ----------

final contentReviewRepositoryProvider = Provider<ContentReviewRepository>(
  (ref) => InMemoryContentReviewRepository(),
);

/// Admin content studio: paste target-language text, extract review
/// candidates, approve/reject. State = (ingestion result, review log).
class ContentStudioState {
  const ContentStudioState({this.result, this.review = const ContentReviewLog()});

  final IngestionResult? result;
  final ContentReviewLog review;

  ContentStudioState copyWith({
    IngestionResult? result,
    ContentReviewLog? review,
  }) => ContentStudioState(
    result: result ?? this.result,
    review: review ?? this.review,
  );
}

class ContentStudioController extends Notifier<ContentStudioState> {
  @override
  ContentStudioState build() => const ContentStudioState();

  /// Extracts candidates from [text] for the selected language.
  void ingest(String text) {
    final curriculum = ref.read(curriculumProvider).value;
    if (curriculum == null || text.trim().isEmpty) return;
    state = ContentStudioState(
      result: ingestLanguageText(
        text,
        graph: curriculum.graph,
        languageCode: curriculum.languageCode,
      ),
      review: const ContentReviewLog(),
    );
  }

  Future<void> approve(String id) async {
    state = state.copyWith(review: state.review.approve(id));
    // Merge the approved candidate into the live curriculum/stories.
    final c = state.result?.candidates.where((c) => c.id == id).firstOrNull;
    if (c != null) ref.read(approvedContentProvider.notifier).add(c);
    await ref.read(contentReviewRepositoryProvider).save(state.review);
  }

  Future<void> reject(String id) async {
    state = state.copyWith(review: state.review.reject(id));
    ref.read(approvedContentProvider.notifier).remove(id);
    await ref.read(contentReviewRepositoryProvider).save(state.review);
  }

  void clear() => state = const ContentStudioState();
}

final contentStudioProvider =
    NotifierProvider<ContentStudioController, ContentStudioState>(
      ContentStudioController.new,
    );

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
    this.traits = const [],
    this.ready = false,
  });

  /// Core learner model — same type the exam flows use (ADR-0008).
  final adaptive.LearnerModel model;
  final MisconceptionLog misconceptions;
  final LanguageSignalsStore signals;

  /// Learning DNA trait names, derived by the core engine after every
  /// answer (never stored — recomputed, per the core's contract).
  final List<String> traits;
  final bool ready;

  Map<String, double> get conceptMastery => {
    for (final e in model.concepts.entries) e.key: e.value.mastery,
  };

  LanguageLearnerState copyWith({
    adaptive.LearnerModel? model,
    MisconceptionLog? misconceptions,
    LanguageSignalsStore? signals,
    List<String>? traits,
    bool? ready,
  }) => LanguageLearnerState(
    model: model ?? this.model,
    misconceptions: misconceptions ?? this.misconceptions,
    signals: signals ?? this.signals,
    traits: traits ?? this.traits,
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
    // Language switch rebuilds the whole learner state for the new
    // curriculum (demo mode: state is per-run anyway).
    ref.watch(selectedLanguageProvider);
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
    // Demo mode: the core model is never persisted, so every (re)build —
    // app start or language switch — starts a fresh learner. The stores
    // MUST match the model or a language switch would leak the previous
    // language's misconceptions/signals into this one (and re-seeding
    // would inflate occurrence counts on every switch round trip).
    // Loading from the repositories returns when LearnerModel persistence
    // lands with the Firestore swap (Phase 8).
    state = state.copyWith(
      misconceptions: const MisconceptionLog(),
      signals: const LanguageSignalsStore(),
      ready: true,
    );
    await ref.read(misconceptionRepositoryProvider).save(state.misconceptions);
    await ref.read(languageSignalsRepositoryProvider).save(state.signals);
    _seedDemo(curriculum);
  }

  /// Records one exercise answer on [node]. Returns the misconceptions
  /// detected by THIS answer (empty when correct or unattributed) so
  /// exercise flows can show teacher feedback immediately.
  Future<List<Misconception>> recordAnswer({
    required LanguageNode node,
    required bool correct,
    required double responseSeconds,
    DateTime? at,
    bool listening = false,
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
    var signals = state.signals.afterAnswer(
      conceptIds: [node.conceptId, ...transferIds.difference({node.conceptId})],
      correct: correct,
      responseSeconds: responseSeconds,
      transferConceptIds: transferIds,
    );
    // A listening exercise also moves listeningRecognition.
    if (listening) {
      signals = signals.afterListening(
        conceptIds: node.lineageConceptIds,
        correct: correct,
      );
    }

    state = state.copyWith(
      model: model,
      misconceptions: misconceptions,
      signals: signals,
      traits: [for (final t in engine.learningDna(model)) t.name],
    );
    await ref.read(misconceptionRepositoryProvider).save(misconceptions);
    await ref.read(languageSignalsRepositoryProvider).save(signals);
    return detected;
  }

  /// Records one conversation turn: moves `conversationAbility` on the
  /// scenario concept's lineage. Signal-only — a conversational turn is
  /// production evidence, not a graded right/wrong answer.
  Future<void> recordConversationTurn({
    required String conceptId,
    required double quality,
  }) async {
    await _initFuture;
    final node = ref.read(curriculumProvider).value?.graph[conceptId];
    final ids = node?.lineageConceptIds ?? [conceptId];
    final signals =
        state.signals.afterConversationTurn(conceptIds: ids, quality: quality);
    state = state.copyWith(signals: signals);
    await ref.read(languageSignalsRepositoryProvider).save(signals);
  }

  /// Records a pronunciation attempt on [node] ([score] 0..1). Updates
  /// pronunciationConfidence beside the core model; the concept's mastery
  /// also moves (a spoken attempt is a real answer: correct if score is
  /// good). Speaking is production, so this is stronger evidence than
  /// recognition.
  Future<void> recordPronunciation({
    required LanguageNode node,
    required double score,
    DateTime? at,
  }) async {
    await _initFuture;
    final engine = _engine;
    if (engine == null) return;
    final when = at ?? DateTime.now();
    final model = engine.applyAnswer(
      state.model,
      adaptive.AnswerEvent(
        questionId: 'sp-${node.conceptId}-${when.microsecondsSinceEpoch}',
        conceptIds: node.lineageConceptIds.reversed.toList(),
        correct: score >= 0.6,
        responseSeconds: 4,
        difficulty01: 0.5,
        answeredAt: when,
      ),
    );
    final signals = state.signals.afterPronunciation(
      conceptIds: [node.conceptId],
      score: score,
    );
    state = state.copyWith(
      model: model,
      signals: signals,
      traits: [for (final t in engine.learningDna(model)) t.name],
    );
    await ref.read(languageSignalsRepositoryProvider).save(signals);
  }

  /// Deterministic demo learner per language (ADR-0006 demo mode):
  /// strong vocabulary, weak grammar with live misconceptions — the
  /// showcase state the Language Lab renders on first launch.
  static const _seedScripts = <String, List<(String, bool, double)>>{
    'es': [
      // Vocabulary: fast and solid, one false-friend slip.
      ('es:a1:vocabulary:food:fruit:manzana', true, 2.1),
      ('es:a1:vocabulary:food:fruit:manzana', true, 1.6),
      ('es:a1:vocabulary:food:fruit:manzana', true, 1.2),
      ('es:a1:vocabulary:food:restaurant:embarazada', false, 6.8),
      ('es:a1:vocabulary:food:restaurant:embarazada', true, 3.0),
      // Grammar: tener-states hit twice (transfer), ser/estar once.
      ('es:a1:grammar:verbs:present-tense:ar-verbs', true, 4.0),
      ('es:a1:grammar:verbs:present-tense:ar-verbs', true, 3.2),
      ('es:a1:grammar:verbs:states:tener-states', false, 8.5),
      ('es:a1:grammar:verbs:states:tener-states', false, 7.9),
      ('es:a1:grammar:verbs:states:ser-estar', false, 9.1),
      ('es:a1:grammar:verbs:states:ser-estar', true, 5.0),
      // A taste of conversation + culture.
      ('es:a1:conversation:ordering-food', true, 12.0),
      ('es:a1:culture:meal-times', true, 4.5),
    ],
    'en': [
      // Vocabulary solid, one false friend (actually/actualmente).
      ('en:a1:vocabulary:everyday:greetings:how-are-you', true, 2.0),
      ('en:a1:vocabulary:everyday:greetings:how-are-you', true, 1.5),
      ('en:a1:vocabulary:everyday:actually', false, 7.2),
      ('en:a1:vocabulary:everyday:actually', true, 3.1),
      // Grammar: pro-drop transfer twice, third-person -s once.
      ('en:a1:grammar:verbs:present-simple:subject-required', false, 8.8),
      ('en:a1:grammar:verbs:present-simple:subject-required', false, 8.1),
      ('en:a1:grammar:verbs:present-simple:third-person-s', false, 6.5),
      ('en:a1:grammar:verbs:present-simple:third-person-s', true, 4.2),
      ('en:a1:conversation:introductions', true, 11.0),
    ],
  };

  void _seedDemo(Curriculum c) {
    var t = DateTime(2026, 7, 15, 9);
    for (final (id, correct, seconds)
        in _seedScripts[c.languageCode] ?? const <(String, bool, double)>[]) {
      final node = c.graph[id];
      if (node == null) continue;
      t = t.add(const Duration(minutes: 3));
      recordAnswer(
        node: node,
        correct: correct,
        responseSeconds: seconds,
        at: t,
      );
    }
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
  LanguagePracticeState? build() {
    ref.watch(selectedLanguageProvider); // language switch ends the session
    return null;
  }

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
          listening: s.current.type == ExerciseType.listening,
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

// ---------- speaking practice (ADR-0020) ----------

class SpeakingState {
  const SpeakingState({
    required this.drills,
    required this.index,
    this.transcript,
    this.score,
    this.words = const [],
    this.listening = false,
    this.finished = false,
  });

  final List<SpeakingDrill> drills;
  final int index;

  /// Last recognized utterance (null before an attempt).
  final String? transcript;

  /// 0..1 score for the current drill (null before an attempt).
  final double? score;

  /// Per-word pronunciation feedback for the current attempt.
  final List<PronWord> words;
  final bool listening;
  final bool finished;

  SpeakingDrill get current => drills[index];
  bool get attempted => score != null;

  SpeakingState copyWith({
    int? index,
    String? transcript,
    double? score,
    List<PronWord>? words,
    bool clearAttempt = false,
    bool? listening,
    bool? finished,
  }) => SpeakingState(
    drills: drills,
    index: index ?? this.index,
    transcript: clearAttempt ? null : (transcript ?? this.transcript),
    score: clearAttempt ? null : (score ?? this.score),
    words: clearAttempt ? const [] : (words ?? this.words),
    listening: listening ?? this.listening,
    finished: finished ?? this.finished,
  );
}

class SpeakingController extends Notifier<SpeakingState?> {
  @override
  SpeakingState? build() {
    ref.watch(selectedLanguageProvider);
    return null;
  }

  void start({List<String> focusConceptIds = const [], int limit = 8}) {
    final curriculum = ref.read(curriculumProvider).value;
    if (curriculum == null) return;
    // Dynamic practice (Phase 21): with no explicit focus, ask the Teacher
    // Brain — weak/recently-active concepts first, rotated by the learner's
    // streak day so consecutive days practice different material. Still
    // deterministic; no repeated fixed drill set.
    var focus = focusConceptIds;
    var offset = 0;
    if (focus.isEmpty) {
      final brain = ref.read(teacherBrainProvider).value;
      if (brain != null) {
        final weak = [
          for (final e in brain.connections.nodes.entries)
            if (!e.value.known && e.value.mastery > 0) e.key,
        ];
        focus = [...brain.connections.recentlyActivated, ...weak];
        offset = brain.identity.streakDays;
      }
    }
    final drills = generateSpeakingDrills(
      curriculum.graph,
      focusConceptIds: focus,
      limit: limit,
    );
    final rotated = drills.isEmpty
        ? drills
        : [...drills.skip(offset % drills.length), ...drills.take(offset % drills.length)];
    state = SpeakingState(drills: rotated, index: 0);
  }

  /// Speaks the target so the learner hears it before attempting.
  Future<void> playTarget() async {
    final s = state;
    if (s == null) return;
    await ref
        .read(speechServiceProvider)
        .speak(s.current.target, langCode: ref.read(languageBcp47Provider));
  }

  /// Listens for the learner's utterance, scores it, records the signal.
  Future<void> attempt() async {
    final s = state;
    if (s == null || s.listening || s.finished) return;
    state = s.copyWith(listening: true);
    // Phase 23: capture through the Whisper pipeline (local model when ready,
    // platform recognizer fallback otherwise) so the attempt becomes a
    // measured SpeakingSession — first-class Teacher Brain evidence.
    final session = await ref.read(whisperPipelineProvider).capture(
      target: s.current.target,
      langCode: ref.read(languageBcp47Provider),
      conceptId: s.current.node.conceptId,
    );
    if (session == null) {
      state = state?.copyWith(listening: false);
      return;
    }
    final result = scorePronunciationDetailed(
      s.current.target,
      session.transcript,
    );
    await ref.read(languageLearnerProvider.notifier).recordPronunciation(
      node: s.current.node,
      score: result.score,
    );
    ref.read(speakingSessionsProvider.notifier).add(session);
    state = state?.copyWith(
      listening: false,
      transcript: session.transcript,
      score: result.score,
      words: result.words,
    );
  }

  void next() {
    final s = state;
    if (s == null || !s.attempted) return;
    if (s.index + 1 < s.drills.length) {
      state = s.copyWith(index: s.index + 1, clearAttempt: true);
    } else {
      state = s.copyWith(finished: true);
    }
  }

  void reset() => state = null;
}

final speakingProvider =
    NotifierProvider<SpeakingController, SpeakingState?>(
      SpeakingController.new,
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
TutorContext? assembleTutorContext(
  Ref ref, {
  String? focusConceptId,
  String? scenarioConceptId,
}) {
  final curriculum = ref.read(curriculumProvider).value;
  if (curriculum == null) return null;
  final learner = ref.read(languageLearnerProvider);
  return buildTutorContext(
    curriculum: curriculum,
    conceptMastery: learner.conceptMastery,
    misconceptions: learner.misconceptions,
    signals: learner.signals,
    goals: [
      'Reach ${ref.read(learnerGoalsProvider).targetLevel.name.toUpperCase()} '
          '${curriculum.languageName}',
    ],
    learningTraits: learner.traits,
    focusConceptId:
        focusConceptId ?? learner.misconceptions.all.firstOrNull?.conceptId,
    scenarioConceptId: scenarioConceptId,
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
  TutorSessionState? build() {
    ref.watch(selectedLanguageProvider); // language switch ends the session
    return null;
  }

  /// Starts a session: assembles fresh context and asks the tutor to open.
  /// Conversation/Immersion pick a scenario weighted to weak concepts.
  Future<void> start(TutorMode mode, {String? focusConceptId}) async {
    String? scenarioId;
    if (mode == TutorMode.conversation || mode == TutorMode.immersion) {
      final curriculum = ref.read(curriculumProvider).value;
      final learner = ref.read(languageLearnerProvider);
      if (curriculum != null) {
        scenarioId = pickScenarioConceptId(
          curriculum.graph,
          weakConceptIds: {
            for (final w in learner.conceptMastery.entries)
              if (w.value < 0.6) w.key,
          },
        );
      }
    }
    final context = assembleTutorContext(
      ref,
      focusConceptId: focusConceptId,
      scenarioConceptId: scenarioId,
    );
    if (context == null) return;
    state = TutorSessionState(mode: mode, context: context, busy: true);
    final reply = await ref.read(languageTutorProvider).respond(
      mode: mode,
      context: context,
      userMessage: 'Start the session.',
    );
    // The teacher opens personally, from what it actually knows (Phase 21):
    // the brain's leading curiosity/observation precedes the lesson opener.
    // Phase 24: a genuine memory reference ("Remember…") makes the teacher
    // feel persistent — drawn from real connections/history, never invented.
    final brain = ref.read(teacherBrainProvider).value;
    final greeting = brain == null ? null : teacherGreeting(brain);
    final memory = brain == null
        ? null
        : ref.read(teacherIntelligenceProvider).memory(brain)?.reference;
    state = state?.copyWith(
      transcript: [
        if (greeting != null) (true, greeting),
        if (memory != null) (true, memory),
        (true, reply.text),
      ],
      busy: false,
    );
  }

  Future<void> send(String rawMessage) async {
    // Input sanitization (Phase 21): strip control/escape artifacts like
    // `\|Si` before anything else sees the message.
    final message = sanitizeUserInput(rawMessage);
    final s = state;
    if (s == null || s.busy || message.isEmpty) return;
    state = s.copyWith(transcript: [...s.transcript, (false, message)], busy: true);

    // Conversation/Immersion: the learner's turn is production — score it
    // and move the conversationAbility signal on the scenario concept.
    if ((s.mode == TutorMode.conversation || s.mode == TutorMode.immersion) &&
        s.context.scenarioConceptId != null) {
      final quality = conversationTurnQuality(message, s.context.targetVocab);
      await ref.read(languageLearnerProvider.notifier).recordConversationTurn(
        conceptId: s.context.scenarioConceptId!,
        quality: quality,
      );
    }

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
    // Dedupe guard (Phase 21): never show the identical tutor reply twice in
    // a row — a repeated line reads as a bug, so acknowledge-and-advance.
    final lastTutor = state?.transcript.lastWhere(
      (t) => t.$1,
      orElse: () => (true, ''),
    );
    final text = reply.text.trim() == lastTutor?.$2.trim()
        ? '${reply.text} ¿Algo más que quieras contarme?'
        : reply.text;
    state = state?.copyWith(
      transcript: [...?state?.transcript, (true, text)],
      busy: false,
    );
  }

  /// Ending a session is a completed lesson (Phase 31): build the typed
  /// outcome + reflection from the run's measured evidence and persist it to
  /// the teacher's long-term memory, so the teacher remembers it next time.
  /// Fire-and-forget, guarded — a bare/empty session records nothing.
  void reset() {
    final s = state;
    state = null;
    if (s == null || s.transcript.length <= 1) return;
    _recordCompletedLesson();
  }

  Future<void> _recordCompletedLesson() async {
    final brain = ref.read(teacherBrainProvider).value;
    if (brain == null) return;
    final speaking = ref.read(speakingSessionsProvider);
    final reading = await ref.read(readingRecordsProvider.future);
    final today = _notebookDay(DateTime.now());
    final result = buildLessonResult(
      brain: brain,
      day: today,
      objective: brain.objectives.current,
      speaking: speaking,
      reading: reading,
    );
    if (result.isEmpty) return;
    final lesson = completedFromResult(
      result,
      reflection: reflectFromLesson(result),
    );
    await ref.read(teacherMemoryRepositoryProvider).appendLesson(lesson);
    ref.read(lessonResultsProvider.notifier).add(result);
    ref.read(teacherMemoryRevisionProvider.notifier).state++;
  }
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

// ---------- Teacher's Notebook (Phase 17) ----------

/// Persistent store for the notebook's cross-session memory. Disk-backed on
/// device; tests override this with an in-memory repository.
final teacherNotebookRepositoryProvider = Provider<TeacherNotebookRepository>(
  (ref) => PrefsTeacherNotebookRepository(),
);

String _notebookDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Mean of a per-concept signal across the concepts that have measured it;
/// null when nothing has been measured yet.
double? _meanSignal(
  LanguageSignalsStore signals,
  double? Function(LanguageConceptSignals) pick,
) {
  final xs = <double>[
    for (final s in signals.byConcept.values)
      if (pick(s) != null) pick(s)!,
  ];
  if (xs.isEmpty) return null;
  return xs.reduce((a, b) => a + b) / xs.length;
}

/// The reasoning engine that assembles the Teacher Brain. Offline and
/// deterministic by default; a premium engine can replace only this provider
/// without touching the model, persistence, or UI.
final reasoningEngineProvider = Provider<ReasoningEngine>(
  (ref) => const OfflineReasoningEngine(),
);

/// The live Teacher Brain (Phase 17) — the single source of truth about the
/// learner, assembled each time the learner's state changes and persisted so
/// the teacher "remembers" across app restarts. Facts come from the app's
/// authoritative captures; observations are generated from those facts. Writes
/// today's metrics snapshot each rebuild (one entry per day, so trends compare
/// against a prior day, not this session).
final teacherBrainProvider = FutureProvider<TeacherBrain?>((ref) async {
  final st = ref.watch(languageLearnerProvider);
  final curriculum = ref.watch(curriculumProvider).value;
  final mastery = ref.watch(languageSkillMasteryProvider);
  final goals = ref.watch(learnerGoalsProvider);
  final repo = ref.watch(teacherNotebookRepositoryProvider);
  final engine = ref.watch(reasoningEngineProvider);
  if (curriculum == null) return null;

  final blocks = ref.watch(dailyLessonProvider);
  final repairBlock = blocks
      .where((b) => b.kind == LessonBlockKind.repair)
      .firstOrNull;
  final nextBlock = blocks
      .where((b) => b.kind != LessonBlockKind.repair)
      .firstOrNull;

  String? nameOf(String? id) =>
      id == null ? null : (curriculum.graph[id]?.name ?? id);
  final nextName =
      nameOf(nextBlock?.conceptIds.firstOrNull) ?? nextBlock?.title;
  final topMisconception = st.misconceptions.all.firstOrNull;
  final currentConceptId =
      repairBlock?.conceptIds.firstOrNull ??
      topMisconception?.conceptId ??
      blocks.firstOrNull?.conceptIds.firstOrNull;
  final currentObjective =
      nameOf(currentConceptId) ?? blocks.firstOrNull?.title ?? 'Warm-up review';

  // Concepts touched by today's plan or a live misconception = recently active.
  final recentlyActivated = <String>{
    for (final b in blocks) ...b.conceptIds,
    for (final m in st.misconceptions.all) m.conceptId,
  };

  final conceptNames = {
    for (final e in curriculum.graph.nodes.entries) e.key: e.value.name,
  };
  final vocabularyPoolSize = curriculum.graph.nodes.keys
      .where((k) => k.contains(':vocabulary:'))
      .length;

  final history = await repo.loadHistory();
  final today = _notebookDay(DateTime.now());
  final previous = history.where((s) => s.day != today).lastOrNull;
  final historyDays = <String>{for (final s in history) s.day, today}.toList();

  // Phase 22: reading records feed lesson history + discovered interests.
  final readingRecords = await ref.watch(readingRecordsProvider.future);
  // Phase 23: speaking sessions (Whisper/fallback) feed lesson history too.
  final speakingSessions = ref.watch(speakingSessionsProvider);
  // Phase 31: persisted completed lessons feed the history so the teacher
  // remembers across restarts (the in-run producer persists them, so this is
  // the single source — no double counting).
  final persistedLessons = await ref.watch(teacherMemoryProvider.future);
  final lessonHistory = [
    ...outcomesFromRecords(readingRecords),
    for (final s in speakingSessions) speakingOutcome(s, today),
    for (final l in persistedLessons) l.toOutcome(),
  ];

  final brain = engine.assemble(
    BrainInputs(
      today: DateTime.now(),
      nativeLanguage: curriculum.nativeLanguage,
      targetLanguage: curriculum.languageCode,
      targetLanguageName: curriculum.languageName,
      baseLevel: 'A1',
      longTermGoal:
          'Reach ${goals.targetLevel.name.toUpperCase()} '
          '${curriculum.languageName}',
      skillMastery: mastery,
      conceptMastery: st.conceptMastery,
      conceptNames: conceptNames,
      misconceptions: st.misconceptions.all,
      accuracy: st.model.overallAccuracy,
      totalAnswered: st.model.totalAnswered,
      learningDna: st.traits,
      historyDays: historyDays,
      vocabularyPoolSize: vocabularyPoolSize,
      relations: curriculum.graph.relations,
      recentlyActivated: recentlyActivated,
      storiesAvailable:
          (ref.watch(storiesProvider).value ?? const []).isNotEmpty,
      history: history,
      currentConceptId: currentConceptId,
      pronunciationConfidence: _meanSignal(
        st.signals,
        (s) => s.pronunciationConfidence,
      ),
      listeningRecognition: _meanSignal(
        st.signals,
        (s) => s.listeningRecognition,
      ),
      conversationAbility: _meanSignal(
        st.signals,
        (s) => s.conversationAbility,
      ),
      previous: previous,
      currentObjective: currentObjective,
      secondaryObjective: nextName ?? 'Keep your skills fresh',
      nextConceptName: nextName,
      interests: discoverInterests(readingRecords),
      lessonHistory: lessonHistory,
    ),
  );

  await repo.saveSnapshot(
    NotebookSnapshot(
      day: today,
      mastery: mastery,
      accuracy: st.model.overallAccuracy,
      misconceptionTotal: st.misconceptions.all.length,
    ),
  );

  return brain;
});

// ---------- Local LLM (Phase 25) ----------

/// Persistent LLM model metadata store (disk on device; overridable).
final llmModelRepositoryProvider = Provider<LlmModelRepository>(
  (ref) => PrefsLlmModelRepository(),
);

/// LLM model lifecycle manager (download/verify/delete/upgrade). Pure logic.
final llmModelManagerProvider = Provider<LlmModelManager>(
  (ref) => LlmModelManager(
    repository: ref.watch(llmModelRepositoryProvider),
    downloader: GgufModelDownloader(),
  ),
);

/// The on-device LLM seam (`AiChatModel`). Not-ready until a GGUF model is
/// loaded on device; the deterministic voice below words the plan meanwhile.
final localLlmProvider = Provider<LocalLlm>((ref) => const LocalLlm());

/// The response pipeline: TeacherBrain → plan → prompt → voice → language
/// policy. Words the teacher's decision offline, without repetition.
final llmPipelineProvider = Provider<LlmPipeline>((ref) => const LlmPipeline());

/// The Teacher Intelligence Engine (Phase 24) — decides WHAT/WHY/WHEN to teach
/// from the brain. A future local LLM (P25) consumes this to word responses;
/// it never decides pedagogy. Pure and offline.
final teacherIntelligenceProvider = Provider<TeacherIntelligenceEngine>(
  (ref) => const TeacherIntelligenceEngine(),
);

/// The teacher's plan for the next turn, derived from the live brain. Null
/// until the brain is ready.
final teacherPlanProvider = Provider<TeacherResponsePlan?>((ref) {
  final brain = ref.watch(teacherBrainProvider).value;
  if (brain == null) return null;
  return ref.watch(teacherIntelligenceProvider).plan(brain);
});

// ---------- Roleplay + lesson outcomes (Phase 30) ----------

/// Completed lesson results this run — measured evidence the Teacher Brain
/// derives outcomes from. Empty by default (a lesson-end producer appends
/// here; cross-session persistence is a documented seam). Not a learner store.
class LessonResultsController extends Notifier<List<LessonResult>> {
  @override
  List<LessonResult> build() {
    ref.watch(selectedLanguageProvider); // reset on language switch
    return const [];
  }

  void add(LessonResult r) => state = [...state, r];
}

final lessonResultsProvider =
    NotifierProvider<LessonResultsController, List<LessonResult>>(
      LessonResultsController.new,
    );

// ---------- Persistent Teacher Memory (Phase 31) ----------

/// Disk-backed teaching history (completed lessons + last roleplay). Tests
/// override with an in-memory repository.
final teacherMemoryRepositoryProvider = Provider<TeacherMemoryRepository>(
  (ref) => PrefsTeacherMemoryRepository(),
);

/// Bumped after every persisted lesson so derived providers reload.
final teacherMemoryRevisionProvider = StateProvider<int>((ref) => 0);

/// The persisted completed lessons — the teacher's long-term memory, restored
/// across restarts.
final teacherMemoryProvider = FutureProvider<List<CompletedLesson>>((ref) async {
  ref.watch(teacherMemoryRevisionProvider);
  return ref.watch(teacherMemoryRepositoryProvider).loadLessons();
});

/// The longitudinal memory summary — achievements, long-term strengths/
/// weaknesses, recurring misconceptions, recovered/forgotten skills, momentum.
/// Derived from persisted lessons + the current brain; null until ready.
final teacherMemorySummaryProvider =
    FutureProvider<TeacherMemorySummary?>((ref) async {
  final brain = ref.watch(teacherBrainProvider).value;
  if (brain == null) return null;
  final lessons = await ref.watch(teacherMemoryProvider.future);
  return summarizeMemory(
    brain: brain,
    lessons: lessons,
    today: _notebookDay(DateTime.now()),
  );
});

// ---------- Reader intelligence (Phase 33) ----------

/// Measured vocabulary history built from the learner's reading records —
/// each unknown word accumulates encounters across books. No estimation.
final vocabularyHistoryProvider =
    FutureProvider<List<VocabularyEntry>>((ref) async {
  final records = await ref.watch(readingRecordsProvider.future);
  final byWord = <String, VocabularyEntry>{};
  final ordered = [...records]..sort((a, b) => a.day.compareTo(b.day));
  for (final r in ordered) {
    for (final w in r.unknownWords) {
      byWord[w] = recordEncounter(
        byWord[w],
        word: w,
        day: r.day,
        lookedUp: true,
        bookId: r.storyId,
      );
    }
  }
  return byWord.values.toList();
});

/// Aggregated, measured reading analytics. Records that carry session
/// measurements (Phase 35/38 reader instrumentation) become session inputs, so
/// duration/pause/replay analytics are real where measured and null elsewhere.
final readingAnalyticsProvider =
    FutureProvider<ReadingAnalyticsReport>((ref) async {
  final records = await ref.watch(readingRecordsProvider.future);
  final sessions = <String, ReadingSessionInput>{
    for (final r in records)
      if (r.durationMs != null ||
          r.pauseCount != null ||
          r.replays != null ||
          r.wordTaps != null)
        r.storyId: ReadingSessionInput(
          record: r,
          durationMs: r.durationMs,
          pauseCount: r.pauseCount,
          paragraphReplays: r.replays,
          pagesRevisited: r.pagesRevisited,
          wordTaps: r.wordTaps,
        ),
  };
  return computeReadingReport(records, sessions: sessions);
});

/// Vocabulary growth derived from the measured vocabulary history.
final vocabularyGrowthProvider = FutureProvider<VocabularyGrowth>((ref) async {
  final history = await ref.watch(vocabularyHistoryProvider.future);
  return computeVocabularyGrowth(
    history,
    today: _notebookDay(DateTime.now()),
  );
});

/// The reader profile — reading confidence, difficulty fit, momentum, habits,
/// insights, prediction, and reading recommendations. Derived each rebuild.
final readerProfileProvider = FutureProvider<ReaderProfile>((ref) async {
  final records = await ref.watch(readingRecordsProvider.future);
  final analytics = await ref.watch(readingAnalyticsProvider.future);
  final vocab = await ref.watch(vocabularyGrowthProvider.future);
  return buildReaderProfile(
    records: records,
    analytics: analytics,
    vocabulary: vocab,
  );
});

/// The single most important reading recommendation, or null.
final topReadingRecommendationProvider = Provider<Recommendation?>((ref) {
  final profile = ref.watch(readerProfileProvider).value;
  final recs = profile?.recommendations ?? const [];
  return recs.isEmpty ? null : recs.first;
});

// ---------- Connection optimization (Phase 34) ----------

/// The connection-network optimization report — weak/strong/suggested bridges,
/// isolated concepts, cluster health, an explainable score. Derived over the
/// existing graph + memory each rebuild; no new graph, no storage.
final connectionOptimizationProvider =
    FutureProvider<ConnectionOptimizationReport?>((ref) async {
  final brain = ref.watch(teacherBrainProvider).value;
  final curriculum = ref.watch(curriculumProvider).value;
  if (brain == null || curriculum == null) return null;
  final memory = await ref.watch(teacherMemorySummaryProvider.future);
  return optimizeConnections(brain, curriculum.graph, memory: memory);
});

/// The clusters view of the optimization report.
final connectionClustersProvider =
    Provider<List<ConnectionCluster>>((ref) =>
        ref.watch(connectionOptimizationProvider).value?.clusters ?? const []);

/// The single highest-value suggested bridge, or null.
final bridgeRecommendationProvider = Provider<SuggestedBridge?>((ref) {
  final bridges =
      ref.watch(connectionOptimizationProvider).value?.suggestedBridges ??
          const [];
  return bridges.isEmpty ? null : bridges.first;
});

// ---------- Recommendations + journeys (Phase 32/33/34) ----------

/// Ranked, explainable recommendations derived from the brain + long-term
/// memory + reader intelligence + connection optimization — all merged into
/// the ONE recommendation list (no second recommendation system). No storage.
final recommendationsProvider =
    FutureProvider<List<Recommendation>>((ref) async {
  final brain = ref.watch(teacherBrainProvider).value;
  if (brain == null) return const [];
  final memory = await ref.watch(teacherMemorySummaryProvider.future);
  final reader = await ref.watch(readerProfileProvider.future);
  final opt = await ref.watch(connectionOptimizationProvider.future);
  final merged = [
    ...recommend(brain, memory: memory),
    ...reader.recommendations,
    ...?opt?.recommendations,
  ]..sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      if (p != 0) return p;
      final u = b.urgency.compareTo(a.urgency);
      if (u != 0) return u;
      return a.id.compareTo(b.id);
    });
  return merged;
});

/// The single most important recommendation (or null).
final topRecommendationProvider = Provider<Recommendation?>((ref) {
  final list = ref.watch(recommendationsProvider).value ?? const [];
  return list.isEmpty ? null : list.first;
});

/// Each engaged domain's journey with assessed health + prediction.
final journeyReportsProvider = FutureProvider<List<JourneyReport>>((ref) async {
  final brain = ref.watch(teacherBrainProvider).value;
  final curriculum = ref.watch(curriculumProvider).value;
  if (brain == null || curriculum == null) return const [];
  final memory = await ref.watch(teacherMemorySummaryProvider.future);
  return assessJourneys(brain, curriculum.graph, memory: memory);
});

/// The roleplay the teacher would run now, chosen deterministically from the
/// brain (Phase 30, Part 5) — recovery/motivation aware, interest-driven,
/// resuming an interrupted scene when one exists. Null until the brain loads.
final roleplaySelectionProvider = Provider<RoleplayScenario?>((ref) {
  final brain = ref.watch(teacherBrainProvider).value;
  if (brain == null) return null;
  return selectRoleplay(brain, continuation: const ConversationContinuation());
});

/// The unified teacher's automatic choice (Phase 18) — which internal strategy
/// to run and why, chosen from the Teacher Brain. Null until the brain is
/// ready. The tutor screen uses this instead of a mode selector.
final teachingChoiceProvider = Provider<TeachingChoice?>((ref) {
  final brain = ref.watch(teacherBrainProvider).value;
  if (brain == null) return null;
  // Phase 33: recommendations now inform the choice (recovery still leads).
  final recs = ref.watch(recommendationsProvider).value ?? const [];
  return chooseTeachingStrategy(brain, recommendations: recs);
});

// ---------- Local Whisper (Phase 23) ----------

/// Persistent Whisper model metadata store (disk on device; overridable).
final whisperModelRepositoryProvider = Provider<WhisperModelRepository>(
  (ref) => PrefsWhisperModelRepository(),
);

/// Model lifecycle manager (download/verify/delete). Pure logic over seams.
final whisperModelManagerProvider = Provider<WhisperModelManager>(
  (ref) => WhisperModelManager(
    repository: ref.watch(whisperModelRepositoryProvider),
    downloader: HttpModelDownloader(),
  ),
);

/// The offline speech-understanding service. Until the local Whisper model is
/// installed and verified on device, this is the platform-recognizer fallback
/// (offline-capable) behind the same interface — the pipeline never changes.
/// When the sherpa Whisper isolate lands, only this binding moves.
final whisperServiceProvider = Provider<WhisperService>(
  (ref) => FallbackWhisperService(ref.watch(speechServiceProvider)),
);

/// The offline speech-in pipeline: mic → Whisper → SpeakingSession analytics.
final whisperPipelineProvider = Provider<WhisperPipeline>(
  (ref) => WhisperPipeline(ref.watch(whisperServiceProvider)),
);

/// Speaking sessions produced this run — evidence the Teacher Brain derives
/// outcomes from (not a duplicate store; cross-restart persistence is a
/// documented seam). Appended by the speaking flow.
class SpeakingSessionsController extends Notifier<List<SpeakingSession>> {
  @override
  List<SpeakingSession> build() {
    ref.watch(selectedLanguageProvider); // reset on language switch
    return const [];
  }

  void add(SpeakingSession s) => state = [...state, s];
}

final speakingSessionsProvider =
    NotifierProvider<SpeakingSessionsController, List<SpeakingSession>>(
      SpeakingSessionsController.new,
    );

// ---------- Learning Experience (Phase 22) ----------

/// Persistent evidence store: reading records, imported books, saved words.
final experienceRepositoryProvider = Provider<ExperienceRepository>(
  (ref) => PrefsExperienceRepository(),
);

/// Bumped after every write so derived providers reload.
final experienceRevisionProvider = StateProvider<int>((ref) => 0);

/// Finished-reading records (evidence the brain derives outcomes/interests
/// from).
final readingRecordsProvider = FutureProvider<List<ReadingRecord>>((ref) async {
  ref.watch(experienceRevisionProvider);
  return ref.watch(experienceRepositoryProvider).loadReadingRecords();
});

/// Books the learner imported (TXT today; PDF/EPUB parser seams pending),
/// parsed into readable stories.
final importedBooksProvider = FutureProvider<List<Story>>((ref) async {
  ref.watch(experienceRevisionProvider);
  final books = await ref.watch(experienceRepositoryProvider).loadImportedBooks();
  // Phase 27: ingest each imported text into real chapters/paragraphs with
  // measured difficulty + topics before it reaches the reader.
  return [
    for (final e in books.entries)
      storyFromIngested(
        id: e.key,
        book: ingestBook(title: e.value.title, author: '', text: e.value.text),
      ),
  ];
});

/// Relationships between the learner's imported books (Phase 27): measured
/// topic + vocabulary overlap, so the teacher can say "you've seen this in
/// another book". Empty until at least two books are imported.
final bookRelationshipsProvider =
    FutureProvider<List<BookRelationship>>((ref) async {
  ref.watch(experienceRevisionProvider);
  final books = await ref.watch(experienceRepositoryProvider).loadImportedBooks();
  final fingerprints = [
    for (final e in books.entries)
      BookFingerprint.fromIngested(
        e.key,
        ingestBook(title: e.value.title, author: '', text: e.value.text),
      ),
  ];
  return relateBooks(fingerprints);
});

/// Records finished stories: mines vocabulary against the learner's real
/// knowledge, persists the measured record, refreshes everything derived
/// from it (brain lesson history, interests, notebook). State = writes done.
class ReadingExperienceController extends Notifier<int> {
  @override
  int build() => 0;

  /// Optional session measurements (Phase 35/38) come from the reader UI —
  /// real clock and real counters, never estimated. Null = uninstrumented.
  Future<void> recordCompletion(
    Story story, {
    int? durationMs,
    int? pauseCount,
    int? replays,
    int? pagesRevisited,
    int? wordTaps,
  }) async {
    // Words actually in the finished text — measured from the story itself.
    final wordsRead =
        story.fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final curriculum = ref.read(curriculumProvider).value;
    if (curriculum == null) return;
    final learner = ref.read(languageLearnerProvider);
    final mined = mineVocabulary(
      story.fullText,
      curriculum,
      learner.conceptMastery,
    );
    final record = buildReadingRecord(
      story: story,
      mined: mined,
      day: _notebookDay(DateTime.now()),
      durationMs: durationMs,
      pauseCount: pauseCount,
      replays: replays,
      pagesRevisited: pagesRevisited,
      wordTaps: wordTaps,
      wordsRead: durationMs == null ? null : wordsRead,
    );
    await ref.read(experienceRepositoryProvider).addReadingRecord(record);
    ref.read(experienceRevisionProvider.notifier).state++;
    state++;
  }

  Future<void> importText({required String title, required String text}) async {
    if (title.trim().isEmpty || text.trim().isEmpty) return;
    final id = 'imported-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    await ref
        .read(experienceRepositoryProvider)
        .saveImportedBook(id, title.trim(), text);
    ref.read(experienceRevisionProvider.notifier).state++;
    state++;
  }
}

final readingExperienceProvider =
    NotifierProvider<ReadingExperienceController, int>(
      ReadingExperienceController.new,
    );

/// Immersion vs Mentor (Phase 21): how much native-language support the
/// teacher SHOWS. Audio is always target-language only, in both modes.
final teacherSupportModeProvider = StateProvider<TeacherSupportMode>(
  (ref) => TeacherSupportMode.mentor,
);

/// The Adaptive Lesson Generator's plan (Phase 19) — the orchestrator's
/// "what next", derived from the Teacher Brain. Null until the brain is ready.
/// Reading/speaking/tutor surfaces read their recommendations from here.
final lessonPlanProvider = Provider<LessonPlan?>((ref) {
  final brain = ref.watch(teacherBrainProvider).value;
  if (brain == null) return null;
  final stories = ref.watch(storiesProvider).value ?? const [];
  final recs = ref.watch(recommendationsProvider).value ?? const [];
  return const AdaptiveLessonGenerator()
      .generate(brain, stories: stories, recommendations: recs);
});

/// Today's personalized plan (ADR-0022): misconception repair first, then
/// spaced-repetition reviews, weak skills, pronunciation, story, talk —
/// budgeted by available time and shaped by Learning DNA.
final dailyLessonProvider = Provider<List<LessonBlock>>((ref) {
  final st = ref.watch(languageLearnerProvider);
  final curriculum = ref.watch(curriculumProvider).value;
  if (curriculum == null) return const [];
  // Spaced-repetition: concepts the core scheduler says are due now.
  // Demo mode has no wall clock in seeds, so treat lapsed concepts (a
  // review the engine has flagged) as due too.
  final now = DateTime(2026, 7, 17, 8);
  final due = <String>{
    for (final e in st.model.concepts.entries)
      if (e.value.isDue(now) || e.value.lapses > 0) e.key,
  };
  return buildDailyLesson(
    conceptMastery: st.conceptMastery,
    graph: curriculum.graph,
    misconceptions: st.misconceptions,
    signals: st.signals,
    dueConceptIds: due,
    traits: st.traits,
    stories: ref.watch(storiesProvider).value ?? const [],
    recentAccuracy: st.model.overallAccuracy,
    availableMinutes: ref.watch(availableMinutesProvider),
  );
});

/// Minutes the learner has today (goal-derived; a selector could set it).
final availableMinutesProvider = Provider<int>(
  (ref) => ref.watch(learnerGoalsProvider).minutesPerDay,
);

// ---------- learner goals (ADR-0026) ----------

class LearnerGoals {
  const LearnerGoals({this.minutesPerDay = 25, this.targetLevel = CefrLevel.a2});

  /// Daily study budget — drives the lesson engine's time allocation.
  final int minutesPerDay;

  /// Desired CEFR level — caps the story queue so learners can read up.
  final CefrLevel targetLevel;

  LearnerGoals copyWith({int? minutesPerDay, CefrLevel? targetLevel}) =>
      LearnerGoals(
        minutesPerDay: minutesPerDay ?? this.minutesPerDay,
        targetLevel: targetLevel ?? this.targetLevel,
      );
}

class LearnerGoalsController extends Notifier<LearnerGoals> {
  @override
  LearnerGoals build() => const LearnerGoals();

  void setMinutes(int minutes) =>
      state = state.copyWith(minutesPerDay: minutes.clamp(5, 60));
  void setTargetLevel(CefrLevel level) =>
      state = state.copyWith(targetLevel: level);
}

final learnerGoalsProvider =
    NotifierProvider<LearnerGoalsController, LearnerGoals>(
      LearnerGoalsController.new,
    );
