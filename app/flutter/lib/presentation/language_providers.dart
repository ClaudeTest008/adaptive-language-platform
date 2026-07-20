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

import 'package:shared_preferences/shared_preferences.dart';

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
import '../language/message_intent.dart';
import '../language/misconceptions.dart';
import '../language/notebook.dart';
import '../language/notebook_repository.dart';
import '../language/pipeline.dart';
import '../language/reasoning_engine.dart';
import '../language/local_llm/llm_memory.dart';
import '../language/local_llm/llm_model_manager.dart';
import '../language/local_llm/llm_pipeline.dart';
import '../language/local_llm/llm_prompt_builder.dart';
import '../language/local_llm/llm_repository.dart';
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
import '../language/teacher_packet.dart';
import '../infrastructure/gguf_teacher_voice.dart';
import '../infrastructure/llm_downloader.dart';
import '../language/whisper/whisper_model_manager.dart';
import '../language/whisper/whisper_pipeline.dart';
import '../language/whisper/whisper_repository.dart';
import '../language/whisper/whisper_service.dart';
import '../infrastructure/sherpa_whisper_service.dart';
import '../infrastructure/whisper_downloader.dart';
import '../language/signals.dart';
import '../language/teacher_brain.dart';
import '../language/speaking.dart';
import '../language/speaking_prompts.dart';
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

/// Voice settings (session-persistent, like themeMode). Engine choice and a
/// playback-speed multiplier the learner sets in Voice Settings.
///
/// DEFAULTS SET BY HUMAN EAR TEST (2026-07-20, same sentence covering vaya /
/// ll / rr / ñ, all three options heard back-to-back on the device):
///   - Device TTS (Google): pronunciation correct, delivery "robotic".
///   - Piper es_MX-claude-high (female): "vaya" still wrong even with the
///     respelling, and the ll/y comes out far too hard.
///   - Piper es_ES-davefx-medium (male): every sound correct, clearly the
///     most natural of the three → SHIPPING DEFAULT.
final speechEngineProvider =
    StateProvider<SpeechEngine>((ref) => SpeechEngine.piper);

/// 0.8x: the ear test found 1.0 and 0.9 both still too fast for a learner.
final speechSpeedProvider = StateProvider<double>((ref) => 0.8);

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

  /// The learner has produced an utterance for this drill. Not the same as
  /// "scored" — a spontaneous-response drill is attempted but unscored.
  bool get attempted => transcript != null;

  /// Instruction line for the current drill's kind.
  String get instruction => current.kind.instruction;

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
  static const _doneKey = 'speaking_completed_v1';

  /// Targets the learner has already completed (persisted): fresh material is
  /// always preferred; completed phrases drop to the back of the queue for
  /// light spaced repetition — never an immediate loop.
  final Set<String> _done = {};
  bool _doneLoaded = false;

  @override
  SpeakingState? build() {
    ref.watch(selectedLanguageProvider);
    _loadDone();
    return null;
  }

  Future<void> _loadDone() async {
    if (_doneLoaded) return;
    _doneLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _done.addAll(prefs.getStringList(_doneKey) ?? const []);
    } catch (_) {
      // No prefs plugin (tests) → in-run only.
    }
  }

  Future<void> _persistDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_doneKey, _done.toList()..sort());
    } catch (_) {}
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
    // Ask for more than we show, so fresh material can displace completed
    // phrases instead of the session looping the same list (repetition fix).
    final graphDrills = generateSpeakingDrills(
      curriculum.graph,
      focusConceptIds: focus,
      limit: limit * 3,
    );
    // Curated everyday prompts add the kinds the graph cannot produce
    // (shadowing, spontaneous response, roleplay lines).
    final drills = <SpeakingDrill>[];
    final seen = <String>{};
    for (final d in [
      ...graphDrills,
      ...curatedSpeakingDrills(languageCode: curriculum.languageCode),
    ]) {
      if (seen.add(d.target)) drills.add(d);
    }
    final rotated = drills.isEmpty
        ? drills
        : [...drills.skip(offset % drills.length), ...drills.take(offset % drills.length)];
    // Fresh-first, completed-last (stable order → deterministic), then cap.
    // A drill already practised never leads the queue again, so consecutive
    // sessions move on to new material while old material stays reachable.
    final fresh = [for (final d in rotated) if (!_done.contains(d.target)) d];
    final repeats = [for (final d in rotated) if (_done.contains(d.target)) d];
    final queue = _mixKinds([...fresh, ...repeats]).take(limit).toList();
    state = SpeakingState(drills: queue, index: 0);
  }

  /// Round-robins the queue across drill kinds so one session is not eight
  /// repeat-after-me drills. Stable within each kind → deterministic.
  static List<SpeakingDrill> _mixKinds(List<SpeakingDrill> drills) {
    final byKind = <SpeakingDrillKind, List<SpeakingDrill>>{};
    for (final d in drills) {
      (byKind[d.kind] ??= []).add(d);
    }
    final out = <SpeakingDrill>[];
    while (out.length < drills.length) {
      for (final kind in SpeakingDrillKind.values) {
        final list = byKind[kind];
        if (list != null && list.isNotEmpty) out.add(list.removeAt(0));
      }
    }
    return out;
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
    if (!s.current.scored) {
      // Free production: there is no correct string to compare against, so
      // there is no honest pronunciation number. Record the utterance, score
      // nothing, and feed no pronunciation signal or speaking session (both
      // are measured against a target that does not exist here).
      state = state?.copyWith(
        listening: false,
        transcript: session.transcript,
      );
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
    if (s == null) return;
    // An attempted drill counts as completed — it will not lead the queue
    // again (spaced repetition keeps it reachable at the back). A skipped
    // drill is not marked done: it was never practised.
    if (s.attempted) {
      _done.add(s.current.target);
      _persistDone();
    }
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
    this.conversation = const ConversationContext(),
    this.roleplay,
    this.latestTranslation,
    this.translating = false,
  });

  final TutorMode mode;
  final TutorContext context;

  /// (isTutor, text) pairs, oldest first.
  final List<(bool, String)> transcript;
  final bool busy;

  /// Conversation-scoped memory for the packet teacher path (Phase 25/35):
  /// recent turns + used phrasings. Session-scoped by design — NOT learner
  /// memory, which lives in the brain/teacher memory.
  final ConversationContext conversation;

  /// Active roleplay scene (Phase 30/35) — null outside roleplay sessions.
  /// Progress persists via the teacher-memory repository, so an interrupted
  /// scene resumes next time.
  final RoleplayProgress? roleplay;

  /// English translation of the LATEST tutor reply, produced on demand when
  /// the reply had no native support half (see [TutorSessionController
  /// .translateLatest]). Cleared whenever a new reply arrives.
  final String? latestTranslation;

  /// True while a translation of the latest reply is being produced.
  final bool translating;

  TutorSessionState copyWith({
    List<(bool, String)>? transcript,
    bool? busy,
    ConversationContext? conversation,
    RoleplayProgress? roleplay,
    String? latestTranslation,
    bool? translating,
    bool clearTranslation = false,
  }) => TutorSessionState(
    mode: mode,
    context: context,
    transcript: transcript ?? this.transcript,
    busy: busy ?? this.busy,
    conversation: conversation ?? this.conversation,
    roleplay: roleplay ?? this.roleplay,
    latestTranslation:
        clearTranslation ? null : (latestTranslation ?? this.latestTranslation),
    translating: clearTranslation ? false : (translating ?? this.translating),
  );
}

/// Whether tutor replies are spoken aloud automatically. App-level (settings)
/// rather than session-local, so the AI Tutor settings screen owns it; the
/// mic conversation flow still switches it on when the learner talks.
final tutorVoiceRepliesProvider = StateProvider<bool>((ref) => false);

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
    // Phase 35 activation: when the brain is ready, every live reply comes
    // from the packet teacher path — TeacherIntelligence plans, the
    // deterministic voice words, the language pipeline gates speech
    // (Phase 24/25). The prompt it builds is what a real GGUF model will
    // consume in P36; only the wording generator changes then. The legacy
    // LanguageTutor/DemoTutorModel path remains the fallback while the brain
    // is still loading.
    final brain = ref.read(teacherBrainProvider).value;
    String openerText;
    ConversationContext conversation = const ConversationContext();
    if (brain != null) {
      final response = await ref.read(llmPipelineProvider).respond(
            brain: brain,
            context: conversation,
            userMessage: 'Start the session.',
            supportMode: ref.read(teacherSupportModeProvider),
            generate: await _neuralGenerator(),
            learnerIntent: LearnerIntent.unknown, // teacher opens, learner silent
            learnerFacts: ref.read(learnerFactsProvider),
            packet: _buildPacket(brain, conversation),
            learnerProducedTarget: false, // nothing to correct at the opener
          );
      openerText = response.text;
      conversation = response.context;
    } else {
      final reply = await ref.read(languageTutorProvider).respond(
        mode: mode,
        context: context,
        userMessage: 'Start the session.',
      );
      openerText = reply.text;
    }
    // The teacher opens personally, from what it actually knows (Phase 21):
    // the brain's leading curiosity/observation precedes the lesson opener.
    // Phase 24: a genuine memory reference ("Remember…") makes the teacher
    // feel persistent — drawn from real connections/history, never invented.
    final greeting = brain == null ? null : teacherGreeting(brain);
    final memory = brain == null
        ? null
        : ref.read(teacherIntelligenceProvider).memory(brain)?.reference;
    // The teacher states today's goal up front (Priority 1: the teacher
    // leads; the learner never wonders what to talk about). Objective +
    // secondary come from the brain — real plan, not a script.
    // One language only: objective names are English curriculum labels, and
    // a mixed-language sentence gets carved up by the speech splitter (the
    // first device run showed 'Plan de hoy: Después: Food.'). A fully-native
    // line renders as-is and is never spoken — exactly right for a plan card.
    String? goal;
    if (brain != null) {
      final obj = brain.objectives;
      final hasSecond = obj.secondary.trim().isNotEmpty;
      goal = "Today's plan: ${obj.current}."
          '${hasSecond ? ' Then: ${obj.secondary}.' : ''}';
    }
    state = state?.copyWith(
      transcript: [
        if (greeting != null) (true, greeting),
        if (memory != null) (true, memory),
        if (goal != null) (true, goal),
        (true, openerText),
      ],
      busy: false,
      conversation: conversation,
    );
  }

  /// Assembles the full TeacherPacket for the prompt (Defect 3 repair): the
  /// single serialization of everything the teacher knows — memory,
  /// recommendations, reader, connections, learner-shared facts. Best-effort:
  /// providers that have not resolved yet contribute nothing.
  TeacherPacket? _buildPacket(TeacherBrain brain, ConversationContext ctx) {
    final curriculum = ref.read(curriculumProvider).value;
    if (curriculum == null) return null;
    return buildTeacherPacket(
      brain: brain,
      graph: curriculum.graph,
      context: ctx,
      supportMode: ref.read(teacherSupportModeProvider),
      memory: ref.read(teacherMemorySummaryProvider).value,
      recommendations: ref.read(recommendationsProvider).value ?? const [],
      reader: ref.read(readerProfileProvider).value,
      optimization: ref.read(connectionOptimizationProvider).value,
      roleplay: state?.roleplay?.scenario,
      learnerFacts: ref.read(learnerFactsProvider),
    );
  }

  /// Phase 36: returns the real GGUF wording generator when — and only when —
  /// a verified model is installed AND the engine loads. Anything else → null
  /// → the deterministic voice words the plan. Never fabricates readiness.
  /// Produces an English rendering of the LATEST tutor reply for the
  /// Translate reveal. Three honest tiers:
  ///
  /// 1. The reply's own native support half — shown directly by the UI, this
  ///    method is not called for it.
  /// 2. The on-device GGUF model translating the Spanish (when installed) —
  ///    a real translation, produced by the same generator seam as replies.
  /// 3. A deterministic word-by-word vocabulary gloss from the curriculum.
  ///
  /// Never placeholder text: when none of these exist, the reveal keeps its
  /// honest "spoken in the target language only" note.
  Future<void> translateLatest() async {
    final s = state;
    if (s == null || s.translating || s.latestTranslation != null) return;
    final text =
        s.transcript.lastWhere((t) => t.$1, orElse: () => (false, '')).$2;
    if (text.trim().isEmpty) return;
    final target = ref.read(selectedLanguageProvider);
    final native = target == 'es' ? 'en' : 'es';
    // Tier 1 exists → the UI already shows it; nothing to produce.
    if (splitTeacherReply(text, target, native).support.trim().isNotEmpty) {
      return;
    }
    // Tier 1.5: lines the deterministic voice authored carry an authored
    // English half — exact, free, and never a guess.
    final authored = authoredTranslation(text);
    if (authored != null) {
      state = s.copyWith(latestTranslation: authored, translating: false);
      return;
    }
    state = s.copyWith(translating: true);
    String? translation;
    try {
      final generate = await _neuralGenerator();
      if (generate != null) {
        final neural = await generate(LlmPrompt(
          system:
              'You are a translator. Translate the following Spanish message '
              'into natural English. Reply with ONLY the English translation, '
              'nothing else.',
          user: text,
          constraints: LlmConstraints(
            targetLanguage: native,
            nativeLanguage: target,
            mentorMode: true,
            maxCorrections: 0,
          ),
        ));
        if (neural != null && neural.trim().isNotEmpty) {
          translation = neural.trim();
        }
      }
    } catch (_) {
      // Model failure → fall through to the gloss; never a crash.
    }
    if (translation == null) {
      final curriculum = ref.read(curriculumProvider).value;
      if (curriculum != null) {
        final gloss = vocabularyGloss(text, curriculum);
        if (gloss.isNotEmpty) translation = 'Word by word: $gloss';
      }
    }
    state = state?.copyWith(
      translating: false,
      latestTranslation: translation,
    );
  }

  Future<Future<String?> Function(LlmPrompt prompt)?> _neuralGenerator({
    void Function(String partial)? onPartial,
  }) async {
    try {
      final state = await ref.read(llmModelManagerProvider).status();
      final path = state.info?.path;
      if (!state.isReady || path == null) return null;
      final voice = ref.read(ggufTeacherVoiceProvider);
      if (!await voice.ensureLoaded(path)) return null;
      // Stream partial tokens to the UI as they arrive. The spec's template
      // suffix (e.g. Qwen3 `/no_think`) rides on the system prompt — template
      // plumbing, not evaluation content.
      final suffix = ref.read(selectedLlmSpecProvider).systemSuffix;
      return (prompt) => voice.word(
            suffix.isEmpty
                ? prompt
                : LlmPrompt(
                    system: '${prompt.system}$suffix',
                    user: prompt.user,
                    history: prompt.history,
                    constraints: prompt.constraints,
                  ),
            onPartial: onPartial,
          );
    } catch (_) {
      return null; // any failure = honest fallback, never a crash
    }
  }

  /// Starts (or resumes) a roleplay scene (Phase 30/35). The engine selects
  /// the scenario from the brain; a matching interrupted scene saved in
  /// teacher memory resumes at its stage. Requires the brain (packet path).
  /// [preserveSession] keeps the current transcript/conversation (a mid-chat
  /// "can we practice ordering food?" flows into the scene naturally).
  Future<void> startRoleplay({
    bool preserveSession = false,
    RoleplayKind? requestedKind,
  }) async {
    final brain = ref.read(teacherBrainProvider).value;
    final context = assembleTutorContext(ref);
    if (brain == null || context == null) return;
    final repo = ref.read(teacherMemoryRepositoryProvider);
    final saved = await repo.loadRoleplay();
    // An explicit scene request skips resume; the requested kind is built.
    final scenario = selectRoleplay(
      brain,
      requestedKind: requestedKind,
      continuation: const ConversationContinuation(),
    );
    final resumeIndex = (saved != null &&
            !saved.done &&
            saved.kind == scenario.kind &&
            saved.stageIndex < scenario.stages.length)
        ? saved.stageIndex
        : 0;
    final progress = RoleplayProgress(
      scenario: scenario,
      currentStageIndex: resumeIndex,
    );
    // Persist immediately — the scene survives an interruption from turn one.
    await repo.saveRoleplay(RoleplayMemory(
      title: scenario.title,
      kind: scenario.kind,
      stageIndex: resumeIndex,
      done: false,
      day: _notebookDay(DateTime.now()),
    ));
    final stage = progress.currentStage;
    final current = state;
    // Scene transitions should feel like a teacher changing the subject, not
    // a jump cut: when we are already mid-scene, close the old one first.
    final switching = preserveSession &&
        current?.roleplay != null &&
        current!.roleplay!.scenario.kind != scenario.kind;
    final sceneLines = <(bool, String)>[
      if (switching) (true, 'Muy bien, dejamos esa escena. Cambiamos de sitio.'),
      // Spanish-first, properly punctuated. The old form
      // '<title> — <setting>. <rationale>' mixed English title/rationale into
      // one Spanish sentence, and the speech splitter carved it into an
      // orphan bubble ("un café tranquilo.") with a run-on English support
      // line ("A friendly chat A general conversation to keep momentum.").
      (
        true,
        'Vamos a una escena: ${scenario.setting}. ¡Empecemos! '
            '— In English: ${scenario.title}. ${scenario.rationale}'
      ),
      if (resumeIndex > 0) (true, 'Seguimos donde lo dejamos.'),
      if (stage != null) (true, stage.prompt.text),
    ];
    state = preserveSession && current != null
        ? current.copyWith(
            transcript: [...current.transcript, ...sceneLines],
            roleplay: progress,
          )
        : TutorSessionState(
            mode: TutorMode.conversation,
            context: context,
            roleplay: progress,
            transcript: sceneLines,
          );
  }

  Future<void> send(String rawMessage) async {
    // Input sanitization (Phase 21): strip control/escape artifacts like
    // `\|Si` before anything else sees the message.
    final message = sanitizeUserInput(rawMessage);
    final s = state;
    if (s == null || s.busy || message.isEmpty) return;
    // A new exchange invalidates the on-demand translation of the old reply.
    state = s.copyWith(
      transcript: [...s.transcript, (false, message)],
      busy: true,
      clearTranslation: true,
    );

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

    // Conversation repair: deterministically read the message FIRST — the
    // teacher reacts to what was actually said.
    final intent = classifyLearnerMessage(message);
    final newFacts = extractLearnerFacts(message);
    if (newFacts.isNotEmpty) {
      ref.read(learnerFactsProvider.notifier).record(newFacts);
    }

    // A roleplay request starts (or switches to) the requested scene in-place.
    // An explicit scene ("you are a waiter") steers the scenario kind; a bare
    // request without one only starts when not already in a scene.
    final requestedScene = roleplayKindFromRequest(message);
    if (intent == LearnerIntent.roleplayRequest &&
        (s.roleplay == null || requestedScene != null)) {
      await startRoleplay(preserveSession: true, requestedKind: requestedScene);
      state = state?.copyWith(busy: false);
      return;
    }

    // The TEACHER decides when to roleplay (Priority 1: the teacher leads):
    // when the lesson arc reaches its challenge stage and no scene is
    // running, the teacher opens one — applied practice with today's
    // material, not a feature the learner must discover.
    // Only a plain conversational beat may be redirected into the scene: a
    // question, a request, or anything answerable from facts keeps its
    // normal handling (the first version of this hijacked "What is my
    // name?" into the roleplay).
    final upcomingTurn = s.conversation.turns.length + 1;
    if (s.roleplay == null &&
        intent == LearnerIntent.statement &&
        answerFromFacts(message, ref.read(learnerFactsProvider)) == null &&
        ref
                .read(teacherIntelligenceProvider)
                .stageForTurn(upcomingTurn) ==
            LessonStage.challenge) {
      // Record the learner's turn first so the conversation stays honest.
      state = s.copyWith(
        conversation: s.conversation
            .withTurn(ConversationTurn(fromLearner: true, text: message)),
      );
      await startRoleplay(preserveSession: true);
      state = state?.copyWith(busy: false);
      return;
    }

    // Live streaming bubble (Step 3): the model fills this in token-by-token,
    // so the learner sees words appear instead of waiting for the whole reply.
    final liveIndex = state?.transcript.length ?? 0;
    state = state?.copyWith(transcript: [...?state?.transcript, (true, '')]);
    void onPartial(String partial) {
      final t = [...?state?.transcript];
      if (liveIndex < t.length && t[liveIndex].$1) {
        t[liveIndex] = (true, partial);
        state = state?.copyWith(transcript: t);
      }
    }

    // Phase 35 activation: packet teacher path when the brain is ready,
    // legacy LanguageTutor fallback otherwise (same rule as start()).
    final brain = ref.read(teacherBrainProvider).value;
    String replyText;
    ConversationContext? nextConversation;
    if (brain != null) {
      final withLearner = s.conversation
          .withTurn(ConversationTurn(fromLearner: true, text: message));
      final response = await ref.read(llmPipelineProvider).respond(
            brain: brain,
            context: withLearner,
            userMessage: message,
            supportMode: ref.read(teacherSupportModeProvider),
            generate: await _neuralGenerator(onPartial: onPartial),
            learnerIntent: intent,
            learnerFacts: ref.read(learnerFactsProvider),
            packet: _buildPacket(brain, withLearner),
            // Only an actual Spanish attempt is correctable production; an
            // English chat message is conversation, never a grammar target.
            learnerProducedTarget: looksLikeSpanish(message),
          );
      replyText = response.text;
      nextConversation = response.context;
    } else {
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
      replyText = reply.text;
    }
    // Dedupe guard (Phase 21): never show the identical tutor reply twice in
    // a row. Compare against the tutor bubble BEFORE the live streaming bubble
    // (the live bubble already holds this reply, so it must be skipped).
    final tr = state?.transcript ?? const [];
    var priorTutorText = '';
    for (var i = 0; i < liveIndex && i < tr.length; i++) {
      if (tr[i].$1) priorTutorText = tr[i].$2;
    }
    final text = replyText.trim().isNotEmpty &&
            replyText.trim() == priorTutorText.trim()
        ? '$replyText ¿Algo más que quieras contarme?'
        : replyText;

    // Roleplay loop (Phase 30/35): each learner turn moves the scene one
    // stage forward (measured participation); progress persists so an
    // interrupted scene resumes. Stage prompts are engine-authored.
    RoleplayProgress? nextRoleplay;
    String? stageLine;
    final rp = s.roleplay;
    // Meta-turns PAUSE the scene rather than advancing it — asking the
    // teacher something is not playing your line. Everything else
    // (statements, greetings inside the scene, free Spanish) advances.
    const metaIntents = {
      LearnerIntent.question,
      LearnerIntent.confusion,
      LearnerIntent.grammarRequest,
      LearnerIntent.exampleRequest,
      LearnerIntent.translationRequest,
      LearnerIntent.vocabularyRequest,
      LearnerIntent.practiceRequest,
    };
    final scenePlay = !metaIntents.contains(intent);
    if (rp != null && !rp.done && scenePlay) {
      nextRoleplay = advanceRoleplay(rp);
      stageLine = nextRoleplay.done
          // Closing a scene hands the conversation back instead of just
          // stopping — the learner is never left staring at a dead end.
          ? '¡Escena completada! Lo hiciste muy bien. '
              'Seguimos hablando cuando quieras.'
          : nextRoleplay.currentStage?.prompt.text;
      await ref.read(teacherMemoryRepositoryProvider).saveRoleplay(
            RoleplayMemory(
              title: rp.scenario.title,
              kind: rp.scenario.kind,
              stageIndex: nextRoleplay.currentStageIndex,
              done: nextRoleplay.done,
              day: _notebookDay(DateTime.now()),
            ),
          );
    }

    // Replace the live streaming bubble with the finalized text (dedupe /
    // roleplay applied), then append any scene stage line.
    final finalTranscript = [...?state?.transcript];
    if (liveIndex < finalTranscript.length) {
      finalTranscript[liveIndex] = (true, text);
    } else {
      finalTranscript.add((true, text));
    }
    if (stageLine != null) finalTranscript.add((true, stageLine));
    state = state?.copyWith(
      transcript: finalTranscript,
      busy: false,
      conversation: nextConversation,
      roleplay: nextRoleplay,
    );
  }

  /// Ending a session is a completed lesson (Phase 31): build the typed
  /// outcome + reflection from the run's measured evidence and persist it to
  /// the teacher's long-term memory, so the teacher remembers it next time.
  /// Fire-and-forget, guarded — a bare/empty session records nothing.
  void reset() {
    // Phase 36: abort any in-flight neural generation with the session.
    ref.read(ggufTeacherVoiceProvider).cancel();
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
/// Which candidate wording model is active (model-evaluation framework).
/// Persisted so a benchmark selection survives restarts; defaults to the
/// baseline. Guarded prefs — test-safe.
class SelectedLlmSpecController extends Notifier<LlmModelSpec> {
  static const _key = 'selected_llm_spec_v1';

  @override
  LlmModelSpec build() {
    _load();
    return llmDefaultSpec;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_key);
      final match = llmModelSpecs.where((s) => s.id == id);
      if (match.isNotEmpty) state = match.first;
    } catch (_) {}
  }

  Future<void> select(LlmModelSpec spec) async {
    state = spec;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, spec.id);
    } catch (_) {}
  }
}

final selectedLlmSpecProvider =
    NotifierProvider<SelectedLlmSpecController, LlmModelSpec>(
        SelectedLlmSpecController.new);

final llmModelManagerProvider = Provider<LlmModelManager>(
  (ref) => LlmModelManager(
    repository: ref.watch(llmModelRepositoryProvider),
    downloader: GgufModelDownloader(),
    spec: ref.watch(selectedLlmSpecProvider),
  ),
);

/// The response pipeline: TeacherBrain → plan → prompt → voice → language
/// policy. Words the teacher's decision offline, without repetition.
final llmPipelineProvider = Provider<LlmPipeline>((ref) => const LlmPipeline());

/// Facts the learner EXPLICITLY shared in conversation (name, city, family,
/// reason for learning…). NOT TeacherBrain evidence — the brain stays
/// measured-only; this is a separate, honest store of things the learner
/// literally said, persisted so the teacher remembers across sessions.
class LearnerFactsController extends Notifier<Map<String, String>> {
  static const _key = 'learner_shared_facts_v1';

  @override
  Map<String, String> build() {
    ref.watch(selectedLanguageProvider); // facts survive language switches
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
      state = {...decoded, ...state};
    } catch (_) {
      // No prefs plugin (tests) → in-run only. Never crashes.
    }
  }

  /// Merges newly-stated facts (newest wins) and persists best-effort.
  void record(Map<String, String> facts) {
    if (facts.isEmpty) return;
    state = {...state, ...facts};
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state));
    } catch (_) {}
  }
}

final learnerFactsProvider =
    NotifierProvider<LearnerFactsController, Map<String, String>>(
        LearnerFactsController.new);

/// Phase 36: the real on-device GGUF wording generator (llama.cpp via
/// llamadart). Long-lived singleton — the engine owns the loaded model.
final ggufTeacherVoiceProvider =
    Provider<GgufTeacherVoice>((ref) => GgufTeacherVoice());

/// The Teacher Intelligence Engine (Phase 24) — decides WHAT/WHY/WHEN to teach
/// from the brain. A future local LLM (P25) consumes this to word responses;
/// it never decides pedagogy. Pure and offline.
final teacherIntelligenceProvider = Provider<TeacherIntelligenceEngine>(
  (ref) => const TeacherIntelligenceEngine(),
);

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
/// Phase 37: real offline Whisper (sherpa-onnx OfflineRecognizer on a
/// background isolate + raw PCM capture). The platform recognizer remains the
/// automatic fallback — no model / mic denied / decode failure never breaks
/// the speaking flow. Plugin objects are created lazily inside the service,
/// so tests without a device never touch them.
final whisperServiceProvider = Provider<WhisperService>(
  (ref) => SherpaWhisperService(
    fallback: FallbackWhisperService(ref.watch(speechServiceProvider)),
    manager: ref.watch(whisperModelManagerProvider),
  ),
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

/// Whether the learner has the Translate reveal on for the tutor's most-recent
/// reply. Session-scoped (resets on app restart / language switch). No new AI
/// call — the reveal shows the native-language half the teacher already wrote
/// (`splitTeacherReply.support`).
final tutorTranslateProvider = StateProvider<bool>((ref) {
  ref.watch(selectedLanguageProvider); // a language switch resets the toggle
  return false;
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
