# Changelog

All notable changes to the Adaptive Language Platform are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Changes before 2026-07-12 belong to the exam-platform lineage; see git history and the original `adaptive-exam-platform` repository.

## [Unreleased]

### Added

- **Phase 35 (increment 7) — Packet teacher path ACTIVATED in the live tutor.**
  Every tutor reply now flows TeacherBrain → TeacherIntelligence plan →
  DeterministicTeacherVoice → language-pipeline speech gate (`LlmPipeline`,
  Phase 24/25) whenever the brain is ready; the legacy LanguageTutor/
  DemoTutorModel path remains only as the fallback while the brain is still
  loading. `TutorSessionState` gains the session-scoped `ConversationContext`
  (P25 conversation memory — not learner state); start/send thread it through
  `LlmPipeline.respond` (pipeline itself untouched). Conversation scoring and
  the dedupe guard are unchanged. P36 (real GGUF) now only swaps the wording
  generator — the decision path is already live. 428 tests (+1 controller
  regression: conversation memory advances only on the packet path, replies
  non-empty, and an identical replayed session yields an identical transcript —
  determinism proven). analyze clean; apk debug green. Not device-verified.

- **Phase 35 (increment 6) / Phase 38 core — Reader session instrumentation.**
  The reader now MEASURES sessions: wall-clock duration, pauses (playback
  interruptions), paragraph replays, page revisits, word look-ups, and words
  read — real counters in the UI layer, engines stay pure. Measurements ride on
  `ReadingRecord` (new nullable fields + json; legacy records read back as
  nulls — single store, persistence free). `recordCompletion` passes them;
  `readingAnalyticsProvider` turns measured records into `ReadingSessionInput`
  sessions, so `computeReadingReport` now yields REAL `meanDurationMs`,
  `replayCount`, `pauseFrequency` (new aggregation: mean pauses per session)
  and `wordsPerMinute` (new: wordsRead/duration) — all previously structurally
  null. Null stays null where nothing was measured. 427 tests (+3: json
  round-trip incl. legacy, buildReadingRecord pass-through, provider→report
  end-to-end with real WPM/pauses). analyze clean; apk debug green. Not
  device-verified.

- **Phase 35 (increment 5) — Reader profile surfaced in the Library.** The Phase
  33 Reader Intelligence profile (`readerProfileProvider`) was consumed by no
  screen. Added a read-only **"Your reading"** card at the top of the Reading
  Library (`_ReaderProfileCard` + exhaustive `_fitLabel`) showing books finished,
  comprehension, difficulty fit and the first insight. Hidden entirely while the
  profile is empty (no finished books) — never fabricated. Placed in the Library
  (not the dashboard) because reading intelligence belongs where reading lives
  and the dashboard already has five sections. No engine/provider/state added.
  424 tests (+1 deterministic widget test — first widget test for the stories
  screen, safe because `storiesProvider` is overridden so no rootBundle flake).
  `flutter analyze` clean; `flutter build apk --debug` green. Not device-verified.

- **Phase 35 (increment 4) — Suggested practice scene surfaced.** The Phase 30
  Roleplay Engine (`roleplaySelectionProvider`) was computed but consumed by no
  screen. Added a read-only **"Suggested practice scene"** dashboard section
  (`_RoleplaySuggestionCard` + exhaustive `_roleplayDifficultyLabel`) showing the
  scene the teacher would run now — title, setting, difficulty, rationale.
  Read-only preview; no engine/provider/state added; TeacherBrain and all
  reasoning engines untouched. Null → honest "not yet" line. Starting the scene
  is deferred (needs a roleplay session loop). 423 tests (+1 deterministic widget
  test with a fixed `RoleplayScenario`). `flutter analyze` clean;
  `flutter build apk --debug` green. Not device-verified.

- **Phase 35 (increment 3) — Learning journeys surfaced.** The Phase 32 Journey
  Engine (`journeyReportsProvider`) was computed but consumed by no screen. Added
  a read-only **"Your learning journeys"** dashboard section (`_JourneysCard` +
  `_journeyRow` + exhaustive `_journeyHealthLabel`) showing each engaged domain's
  path — name, assessed health, progress bar, next milestone. Purely derived and
  read-only; no engine/provider/state added; TeacherBrain and all reasoning
  engines untouched. Empty list renders an honest "no journeys yet" line. 422
  tests (+1 deterministic widget test with a fixed `JourneyReport`).
  `flutter analyze` clean; `flutter build apk --debug` green. Not device-verified.

- **Phase 35 (increment 2) — Recommendations become actionable.** The read-only
  "What to focus on next" rows from increment 1 are now tappable: each routes to
  the activity that already exists for its kind, reusing the same session/tab
  primitives as `_launchBlock` (speaking→Speaking tab + session, conversation/
  roleplay→Tutor conversation, reading/story→Library, everything else→the unified
  tutor which reads the same brain). `_launchRecommendation` is exhaustive over
  all 15 kinds (compile error on a new kind); no router push, so the home stays
  testable. No engine/provider/state added; TeacherBrain unchanged. 421 tests
  (+1 deterministic tap test: reading rec → Library tab index). `flutter analyze`
  clean; `flutter build apk --debug` green. Not device-verified.

- **Phase 35 (increment 1) — Surface the Teacher: recommendations on the home.**
  The unified recommendation list (`recommendationsProvider` — Phase 32
  recommendation engine already merged with Phase 33 reader recommendations and
  Phase 34 connection bridges) was computed and tested but consumed by no
  screen. Added a read-only **"What to focus on next"** dashboard section
  (`_TeacherRecommendationsCard` + exhaustive `_recIcon` kind→icon map in
  `language_dashboard_screen.dart`) that shows the top three ranked, explainable
  recommendations. Purely derived and read-only — TeacherBrain stays the single
  source of truth, no new state/engine/provider, no change to Piper/Whisper/
  reasoning/graph. Empty list renders an honest "nothing urgent" line, never a
  fabricated item. 420 tests (+1 deterministic widget test with a fixed
  recommendation list). `flutter analyze` clean; `flutter build apk --debug`
  green. Not device-verified (visual layout on hardware still pending).

### Fixed

- 2026-07-18: Piper ANR crash — FIXED and verified on the physical device
  (OnePlus CPH2037 / Android 12). Root cause (confirmed on-device):
  synchronous ONNX `OfflineTts.generate()` ran on Flutter's UI isolate
  (logcat showed all Piper work on tid == pid == main thread; after
  "LOAD ok" no synthesis returned and the UI froze ~5 min → ANR).
  Fix (`piper_speech_service.dart` only): a single long-lived **background
  isolate** owns the Piper engine — model load + all inference. The UI
  isolate sends text over a SendPort and receives a WAV path, then plays it,
  so the main thread never runs inference. Also: model loads exactly once;
  speech requests are serialized (a `_gen` token cancels the running one on
  a new request/stop — no overlap); `stop()` is instant (playback wait now
  resolves on `onPlayerStateChanged` stopped/completed, the 7 s timeout is
  gone); temp WAVs, ports, isolate and AudioPlayer are disposed; the
  one-time 67 MB extract moved off the UI thread via `compute()`; every op
  is wrapped, logs its full stack, and falls back to device TTS (reported)
  on failure — never crashes. On-device verification (logcat): isolate
  spawned ×1; `LOAD model ok (loadCount=1)` ×1; synthesis runs on the
  isolate (`synth req… (isolate)`, 0.35–2.5 s); 50× rapid Play/Stop with
  barge-in — no crash, no ANR, no extra loads, no exceptions; full-passage
  narration synthesizes + plays; barge-in stops instantly
  (`stop() … instant barge-in`); the UI stays responsive during synthesis
  (language toggle applied + re-rendered mid-synth). `flutter analyze`
  clean; 204 tests green.

### Changed

- 2026-07-17: Piper voice STABILITY INVESTIGATION — diagnostics only, no
  behavior/UI/logic change (fix deferred pending review). Added
  unconditional `[PIPER]` logging (debugPrint survives release builds) at
  every stage: init, ensureVoice (cache-hit / in-flight-join / load count),
  download + extract (with full stack on failure), per-chunk synthesis
  timing (`generate=Nms`, flags >800 ms as a main-isolate block), playback,
  play-timeout detection, `speak()` concurrency counter (`active=N`, flags
  `*** CONCURRENT SPEAK ***`), stop/pause, and a previously-UNHANDLED
  exception path in `speak()` now logging its full stack trace. A 20×
  play/stop stress run on the emulator surfaced the root causes (see
  investigation report): unbounded concurrent `speak()` (peak active=8),
  `stop()` not emitting `onPlayerComplete` so interrupted clauses block for
  the full 7 s timeout, subscription/coroutine pile-up on a single shared
  AudioPlayer, and main-isolate `tts.generate()` (the ANR risk on real
  hardware). No fix applied yet.

- 2026-07-17: Phase 15 revision — "floating voice sidebar" root-caused and
  resolved, with receipts. The vertical floating pill (mic / backspace /
  send / emoji / ☰) over the tutor is **not app UI**: grep proves zero
  `OverlayEntry`/`Overlay`/`FloatingActionButton`/`Positioned` floating
  code exists in `lib/presentation/`, and the tutor input row is exactly
  [Mic][TextField][Send]. Opening the pill's own ☰ menu shows Gboard
  items ("Show on-screen keyboard", "Switch to horizontal toolbar" …): it
  is **Gboard's hardware-keyboard companion toolbar** — the emulator
  reports the host's physical keyboard, so Gboard suppresses the on-screen
  QWERTY and floats its toolbar instead. Fix (device-level):
  `settings put secure show_ime_with_hard_keyboard 1` + Gboard restart —
  the standard **docked QWERTY** now opens on field focus, cursor and
  typing behave like a normal messaging app, and the pill is gone
  (screenshot-verified). No app code changed; nothing existed to delete.

### Added

- 2026-07-18: Phase 34 — Connection Optimization Engine. Pure, deterministic,
  offline; the teacher improves how it reasons over the EXISTING language
  network — no new graph, no duplicate state. `lib/language/connection_optimization.dart`:
  `optimizeConnections(brain, graph, {memory})` reasons over `brain.connections`
  + the curriculum `LanguageKnowledgeGraph` + the long-term memory summary and
  produces a `ConnectionOptimizationReport` — **weak** bridges (low-strength
  edges), **strong** bridges, **suggested** bridges (teaching = reinforce a
  known concept through an unmet neighbour, review = reconnect a forgotten
  concept through an existing edge; future/phonology/etymology/culture/
  pronunciation/idiom are typed `BridgeKind` seams, never emitted until real
  data backs them), **isolated concepts** (engaged but edge-less),
  **ConnectionCluster**s (theme, health, density = intra-edges/possible pairs,
  mastery, coverage, future value, recommendation), overall **density** and
  **ConnectionHealth** (healthy/growing/weak/fragmented/stalled/recovering/
  unknown), and an **explainable optimization score** with a breakdown
  (coverage / density / reinforcement / memory stability). It never synthesizes
  an edge — it only *recommends* bridges; an empty graph yields an empty report.
  Bridge/cluster/isolation findings become **ordinary Recommendations that
  merge into the ONE recommendation list** — so Teacher Intelligence and the
  Adaptive Lesson Generator (which already consume recommendations, Phase 33)
  act on them with no new decision wiring. **TeacherPacket expanded** (additive):
  optimization summary serialized (CONNECTIONS / BRIDGE / ISOLATED, omitted when
  empty). Providers: `connectionOptimizationProvider`, `connectionClustersProvider`,
  `bridgeRecommendationProvider`; `recommendationsProvider` now also merges the
  optimization recommendations. 419 tests (+7: empty-graph no-fabrication,
  teaching bridges from hidden connections, cluster health/density, explainable
  + deterministic score, memory-consumption review bridge, recommendation
  merge + determinism, packet expansion + omission), analyze clean, Android
  debug build green. Fully offline/deterministic; no native/device.

- 2026-07-18: Phase 33 — Reading Completion & Reader Intelligence + closed the
  Phase 32 seam. **Phase 32 follow-up (done first)**: the Recommendation Engine
  is now actually consumed by teaching decisions — `chooseTeachingStrategy` and
  `AdaptiveLessonGenerator.generate` take an optional `recommendations` list;
  recovery/misconception/lagging-speaker branches are UNCHANGED (existing tests
  pass), and a top recommendation only steers the previously-generic default
  branch (planner) or is inserted as a lesson block (generator). Providers wire
  `recommendationsProvider` into both. **Reader Intelligence** — the reader
  becomes a measured learning producer. `lib/language/reading_analytics.dart`
  (pure): `computeReadingReport` aggregates measured signals from reading
  records (comprehension, unknown-word density, longest streak, consistency)
  plus optional per-session instrumentation (replays, completion) — timing/
  pause/WPM are typed nullable seams that stay **null** until the reader UI
  instruments them, never invented. `lib/language/vocabulary_growth.dart`
  (pure): `computeVocabularyGrowth` classifies stable / weak / frequently-
  forgotten / reinforced words + momentum + review candidates from the measured
  vocabulary history; empty history → empty. `lib/language/reader_intelligence.dart`
  (pure): `buildReaderProfile` derives reading confidence, difficulty fit
  (too easy/ideal/too hard/unknown), momentum, habits, strengths/weaknesses,
  insights, a prediction, and reading **Recommendations that merge into the ONE
  Recommendation Engine list** (not a second system). **TeacherPacket expanded**
  (additive): reader profile serialized (READER / READING / REVIEW WORDS,
  omitted when the learner has not read). Providers: `readingAnalyticsProvider`,
  `vocabularyHistoryProvider` (built from records' unknown words),
  `vocabularyGrowthProvider`, `readerProfileProvider`,
  `topReadingRecommendationProvider`; `recommendationsProvider` now merges
  reading recommendations into its ranked output. 412 tests (+10: analytics
  measured/null-when-unmeasured/instrumented, vocabulary growth + empty, reader
  profile confidence/fit/recs/empty/determinism, P32-seam planner + generator +
  regression), analyze clean, Android debug build green. Fully offline/
  deterministic; no native/device.

- 2026-07-18: Phase 32 — Recommendation & Learning Journey Engine. Two new
  pure, deterministic, offline engines; recommendations become another derived
  layer of the Teacher Brain (no parallel state, no persistence — recomputed
  each rebuild). **Recommendation Engine** (`lib/language/recommendation_engine.dart`,
  brain-only): `recommend(brain, {memory})` produces a ranked list of typed
  `Recommendation`s (15 `RecommendationKind`s — continueJourney, recoverWeakConcept,
  review, conversation, roleplay, reading, story, mentalModel, connection,
  speaking, curiosity, milestone, challenge, confidence, celebrate), each with
  id, priority, reason, required concepts, estimated effort, expected value,
  blocking prerequisite, confidence and urgency. Priority is never random —
  recovery beats everything, then active/recurring misconceptions, then
  confidence protection / speaking avoidance, then connections & mental models,
  then celebrate / curiosity, then a stretch. It genuinely **consumes the
  TeacherMemorySummary**: recurring misconceptions rank high, faded skills
  become "reconnect" (never "you forgot"), a declining confidence trend
  triggers a confidence recommendation, recent achievements + positive momentum
  trigger a celebration. Ties break deterministically (urgency → value → id).
  **Learning Journey Engine** (`lib/language/learning_journey_engine.dart`):
  reuses the existing curriculum `LearningJourney` (no second graph) and adds
  `JourneyHealth` (healthy/recovering/plateau/stalled/accelerating/completed,
  from progress + memory momentum + recovery) and `JourneyPrediction`
  (estimated effort, next milestone, likely obstacle = hardest remaining stage,
  required review = faded concepts in the journey) → `assessJourneys`. A domain
  with no engaged concepts yields no journey. **TeacherPacket expanded**
  (additive): top recommendations + journey health/prediction, serialized for
  the LLM (RECOMMEND / JOURNEY HEALTH lines, omitted when absent). Providers:
  `recommendationsProvider`, `topRecommendationProvider`, `journeyReportsProvider`
  (all derived, no storage). 402 tests (+10: recommendation determinism/recovery-
  priority/empty-no-fabrication/memory-consumption/reconnect, journey health +
  prediction + none-for-empty + completed, packet expansion + omission), analyze
  clean, Android debug build green. Fully offline/deterministic; no native/device.

- 2026-07-18: Phase 31 — Persistent Teacher Memory + lesson-completion
  pipeline. Completes the infrastructure Phase 30 left: the teacher now
  genuinely remembers completed lessons across app restarts, all derived from
  measured evidence. **Lesson-end pipeline wired (highest priority)**: ending a
  tutor session (`TutorSessionController.reset`) now automatically builds a
  `LessonResult` + `TeacherReflection` from the run's real speaking/reading
  evidence and persists a `CompletedLesson` — no UI change required; a bare
  session records nothing. **Persistent memory** (`lib/language/teacher_memory.dart`,
  pure): `CompletedLesson` (measured, JSON) + `RoleplayMemory` (resume an
  interrupted scene) + `TeacherMemoryRepository` seam (in-memory default +
  `PrefsTeacherMemoryRepository` disk impl, one-per-day+objective merge,
  capped). **Long-Term Memory Engine** (`lib/language/teacher_memory_engine.dart`,
  pure): `summarizeMemory` derives `TeacherMemorySummary` — recent achievements,
  long-term strengths/weaknesses, recurring misconceptions/connections,
  recovered skills, confidence/motivation trends, learning + teaching momentum,
  lessons completed — everything measured, empty/neutral when no history.
  **Deterministic forgetting**: `decayedConcepts` fades a concept only when it
  is both long-unpracticed AND never strongly held (mastered <3×); strongly-
  mastered concepts stay stable — surfaced as "reconnect" candidates, never
  "you forgot" (connection-first). **Brain integration**: persisted completed
  lessons feed the brain's `lessonHistory` (cross-restart continuity; replaces
  the P30 in-run feed so there is no double-counting). **TeacherPacket
  expanded** (additive): carries the memory summary, serialized for the LLM
  (MEMORY/ACHIEVED/LONG-TERM WEAK/RECOVERED/RECONNECT/RECURRING, omitted when
  empty). Providers: `teacherMemoryRepositoryProvider`, `teacherMemoryProvider`,
  `teacherMemorySummaryProvider`. 392 tests (+11: prefs restart restoration,
  same-day merge, roleplay persist/clear, lesson→completed round-trip, memory
  summary strengths/weaknesses/recovery/trend/momentum, forgetting decay +
  strong-stays + recent-never, packet memory expansion + omission), analyze
  clean, Android debug build green. Fully offline/deterministic — no native or
  device work.

- 2026-07-18: Phase 30 — Adaptive Roleplay + typed Lesson Outcomes + Teacher
  Events (teaching itself becomes data). Three new pure, deterministic, offline
  engines, all derived from the Teacher Brain — no new learner state, no
  duplicate curriculum, nothing fabricated. **Adaptive Roleplay Engine**
  (`lib/language/roleplay_engine.dart`): `selectRoleplay(brain, {continuation})`
  chooses a scenario deterministically — recovery/strained → a gentle
  conversation, an interrupted roleplay is resumed from the continuation,
  otherwise the kind comes from the learner's top interest
  (travel→airport, food→restaurant, …) and difficulty from confidence +
  difficulty-fit. Scenarios EVOLVE through a five-stage arc (open → ask →
  handle-a-mistake → unexpected → natural), not isolated drills; `advanceRoleplay`,
  `roleplayFeedback` (advances only on a solid attempt), `completeRoleplay`.
  **Typed Lesson Outcome Engine** (`lib/language/lesson_outcomes.dart`):
  `buildLessonResult` turns measured speaking sessions + reading records + brain
  state into a rich `LessonResult` (concepts practiced/mastered/struggled,
  connections reinforced, speaking/reading evidence, difficulty, observations,
  strengths/weaknesses) and DERIVES typed events; `toOutcome()` converts to the
  brain's compact `LessonOutcome`; `reflectFromLesson` finally gives
  `TeacherReflection` a real producer. Every field is null/empty when
  unmeasured. **Teacher Event System** (`lib/language/teacher_events.dart`): 15
  typed events (`ConceptLearned`, `MisconceptionResolved`, `SpeakingImproved`,
  `ConnectionDiscovered`, `RoleplayCompleted`, `LessonFinished`, …) as a sealed
  hierarchy carrying day + concept ids + measured evidence + source +
  confidence — no loose strings, JSON-serializable. **TeacherPacket expanded**
  (additive): now carries the roleplay scenario, last-lesson summary, recent
  events and reflection summary, serialized for the local LLM (omitted when
  absent). **Integration**: `roleplaySelectionProvider` (the teacher's chosen
  scenario, live from the brain) and `lessonResultsProvider` feed the brain's
  history additively (empty until a lesson-end producer records results). 381
  tests (+11: roleplay selection/determinism/recovery/resume/advance/feedback,
  lesson result + events + empty-no-fabrication, reflection producer, event
  JSON, packet expansion + omission), analyze clean, Android debug build green.
  Fully offline/deterministic — no native or device work in this phase.

- 2026-07-18: Phase 29 — Speaking analytics upgrade + P28 cache review +
  robustness (**real Whisper inference NOT delivered — see honesty note**).
  Mandatory P28 review done: the cache logic is correct (LRU keeps the playing
  file, prefetch aborts on the generation token, voice-scoped invalidation,
  ordered current→next prefetch); one real nit fixed — `PiperAudioCache.contains`
  has metric side-effects, so prefetch now probes via a new pure `has()` and no
  longer distorts the playback hit rate. **Upgraded speaking analytics**
  (`speaking_session.dart`, pure, measured-only): `analyzeSpeaking` now also
  measures self-corrections (from "no digo / quiero decir / i mean" markers),
  restarts (adjacent word repetitions), speech rate (WPM, null without a
  measured duration), and response latency (when the caller measures it); self-
  corrections now lower behavioural confidence. Nothing estimated — every new
  field is null when unmeasured. **Whisper model manager robustness**: `repair()`
  (verify → on failure delete + redownload) and `storageBytes()` reporting.
  **Voice-pipeline guarantee re-verified** with regression tests: English is
  never in the Spanish-voice output; immersion hides native support, mentor
  keeps it as text. 370 tests (+9), analyze clean, Android debug build green.

  **HONEST — the phase's core goal was NOT met.** Genuine on-device Whisper
  inference requires (a) a raw-PCM microphone-capture plugin (not a dependency
  in this project) and (b) a physical Android device to verify — neither exists
  in this build environment, and I will not add unverifiable native code or
  claim untested functionality. The fallback platform recognizer therefore
  remains the speech-input path; the sherpa `OfflineRecognizer` isolate + PCM
  capture stay a documented seam for a device session. This phase delivered
  only the parts that are real and verifiable offline (analytics, cache fix,
  manager robustness, pipeline regression). No device verification was
  performed; no latency/recognition numbers are claimed.

- 2026-07-18: Phase 28 — Real Piper audio cache + prefetch (playback
  performance; **NOT device-verified — see below**). Wires the pure
  `audio_cache.dart` policy into the real `PiperSpeechService` so identical
  (text, language, voice, speed) audio is synthesized ONCE and reused offline —
  the library should feel like a music app, not an AI generating audio every
  play. **Persistent cache** (`infrastructure/piper_audio_cache.dart`):
  hash-named WAVs on disk (`$docs/piper_cache`), `contains`/`store`/`touch`,
  `cleanup` (LRU via `evictionPlan`, ~200 MB budget, never evicts the file
  currently playing), `invalidateVoice` (voice-scoped — a voice change drops
  only its own audio; the cache key filename now carries readable lang+voice
  prefixes), `clear`, and system metrics (`hitRate`, `sizeBytes` — explicitly
  NOT learner data, never enters the Teacher Brain). **Service wiring**
  (surgical): `speak()` now checks the cache before synthesizing and stores +
  reuses after — the background isolate, generation/barge-in token, serialized
  playback and ANR-fix path are UNCHANGED; cached files are no longer deleted
  after play (`_playFile` gained `deleteAfter`, false for cache). **Prefetch**:
  `PiperSpeechService.prefetch(texts)` synthesizes ahead into the cache without
  playing, aborting the instant a real Play/stop advances the token so it never
  delays the learner. The story reader prefetches the current + next page on
  open and page-turn (best-effort, Piper-only). 361 tests (+8: cache key
  stability + voice-prefix scoping, `PiperAudioCache` store/reuse/LRU-keeps-
  playing/voice-invalidation/clear/no-op-when-cached via real temp dirs),
  analyze clean, Android debug build green.

  **HONEST — device verification NOT performed.** This environment has no
  physical Android device (and can't hear audio), so the required on-device
  checks (first vs cached playback latency, chapter/voice switching, prefetch,
  large-book playback, cache cleanup, cold/warm start, no-ANR under rapid
  play/stop) were NOT run. The change is deliberately surgical and preserves
  the device-verified ANR/barge-in isolate logic, but it touches the most
  safety-critical file in the repo and MUST be verified on hardware before this
  is trusted. No latency numbers are claimed.

- 2026-07-18: Phase 27 — PDF/EPUB backend + Learning Workspace. Turns imported
  books into structured, measurable teaching material. **Book Ingestion Engine**
  (`lib/language/book_ingestion.dart`, pure, no learner data): normalizes raw
  text into chapters (split at Chapter/Capítulo headings), paragraphs and
  sentences; builds a word-frequency index; extracts frequent phrases (bigrams);
  detects language; infers topics from a lexicon; and estimates reading
  difficulty → CEFR from a deterministic readability proxy (avg word + sentence
  length). **Real import backend** (`infrastructure/document_parser.dart`)
  behind the existing seam: **TXT** and **EPUB** are real and offline — EPUB is
  unzipped via `archive`, the OPF spine gives chapter order, XHTML is
  tag-stripped, and `<dc:title>`/`<dc:creator>` metadata is read; format is
  detected from magic bytes, never the filename. **No OCR**: PDFs and scanned
  documents are reported politely ("PDF import needs the text-extraction
  backend… EPUB and TXT work today; scanned PDFs are not supported") and never
  crash. **Reading analytics + vocabulary discovery + book relationships**
  (`lib/language/book_analytics.dart`, pure, measured-only): `ReadingAnalytics`
  (completion; speed/re-read/tap-frequency null unless actually measured);
  `VocabularyEntry` with first/last seen, times encountered/looked-up, source
  book + chapter, context sentences, confidence **null until a real signal
  exists**; `BookRelationship` from measured topic + vocabulary-Jaccard overlap
  (book-to-book, reusing no concept graph) so the teacher can later say "you've
  seen this in another book". **Audio cache policy** (`lib/language/audio_cache.dart`,
  pure): stable FNV-1a hash filenames keyed on text/lang/voice/speed + LRU
  `evictionPlan` — the real Piper wiring lands in P28 and consumes this.
  Imported books now flow through ingestion → `storyFromIngested` (real
  chapters/difficulty/topics/author) into the reader; `bookRelationshipsProvider`
  added. 353 tests (+19: ingestion chapters/language/difficulty/phrases, TXT +
  EPUB (crafted-zip) + PDF-polite parsing, analytics null-when-unmeasured,
  vocabulary merge + JSON, book relationships + none-for-single, audio cache
  key/eviction, ingested→Story), analyze clean, Android debug build green.

- 2026-07-18: Phase 26 — Curriculum Intelligence Engine + Conversation
  Continuity Engine. Two new pure/offline/deterministic engines; neither
  stores learner state, contains UI, or persists anything. **Curriculum
  Intelligence** (`lib/language/curriculum_intelligence.dart`): the teacher now
  understands the LANGUAGE, not just the learner — it reasons over the
  *existing* `LanguageKnowledgeGraph` (prerequisites, typed relations, tiers,
  CEFR) plus the brain; no second graph is built. `CurriculumNode` gives every
  concept a learner-relative view (prerequisites, successors/unlocks,
  connections, difficulty, estimated effort, teaching value, mastery). Queries:
  `missingPrerequisite` (weakest unmet prereq), `blockingConcept` (weak concept
  gating the most successors), `almostMastered` (cheapest win), `nextToStudy`
  (focus prereq → blocker → almost-mastered → highest-value frontier).
  **Learning journeys**: engaged domains become `LearningJourney`s (stages in
  difficulty order, measured progress, current stage, milestone) — "we've been
  working on travel", not "lesson 12"; untouched domains produce no journey.
  **Conversation Continuity** (`lib/language/conversation_continuity.dart`):
  remembers CONVERSATIONS, not the learner (the brain owns that). Typed threads
  — `ConversationArc/Topic`, `OpenQuestion` (asked, unanswered), `TeacherPromise`
  ("next time…"), `PendingExercise`, `RoleplayState`, `ConversationSummary`,
  `ConversationContinuation`. Extracted deterministically from the real
  transcript; an answered question is not open; an empty conversation resumes
  nothing — the teacher starts fresh rather than pretend to remember.
  **Error taxonomy** (`lib/language/error_taxonomy.dart`): 16 typed
  `ErrorCategory`s classified from captured fields (false friend, English
  transfer, verb tense, article gender, preposition, memory lapse vs careless
  by prior mastery + speed, confidence via spoken signals, …), each mapped to a
  distinct `ErrorTeachingStrategy`. **TeacherPacket**
  (`lib/language/teacher_packet.dart`): the ONLY thing a language generator may
  receive — plan + continuation + conversation state + current curriculum node
  + journey + known/unknown concepts + connection opportunities + mental model
  + reflection + correction/language policies + teaching style + objective +
  summary; `serializeTeacherPacket` (deterministic, omits what is absent) and
  `packetPrompt` merge it into the P25 prompt builder — no UI knows the format,
  the LLM stays "dumb". 334 tests (+14: curriculum traversal/prereq resolution/
  next-to-study determinism/journeys + none-fabricated, continuity extraction/
  priority continuation/empty-no-memory/answered-not-open, taxonomy
  classification + distinct strategies, packet derivation + deterministic
  serialization + policy-intact prompt), analyze clean, Android debug build
  green. Engines are library-level this phase (consumed by the packet/prompt
  path); tutor-flow wiring lands with real GGUF inference (P30) to protect
  verified conversation flows. NOT device-verified.

- 2026-07-18: Phase 25 — Local LLM integration (offline). Adds the first
  on-device language-generation layer behind a clean seam. Principle:
  **TeacherBrain decides (WHAT/WHY/WHEN), the LLM only words (HOW), the pipeline
  speaks** — the LLM never decides pedagogy or language policy. `lib/language/
  local_llm/`: `llm_prompt_builder.dart` (pure) converts a `TeacherResponsePlan`
  + brain + conversation context into a structured `LlmPrompt` (system brief =
  intent/stage/pacing/objective/Socratic-or-message/connections/one-correction/
  memory/reflection/mental-model + facts-only grounding + do-not-repeat list) —
  no UI knows the prompt format, nothing fabricated; `LlmConstraints` fixes
  target/native language, mentor/immersion, correction cap. `llm_memory.dart`
  `ConversationContext` — conversation-scoped only (recent turns bounded,
  topic/roleplay/pending/exercise, used-phrasings); NOT learner memory (the
  brain owns that). `local_llm.dart`: `LocalLlm` (`AiChatModel` seam for a
  future GGUF model, reports not-ready until loaded) + `DeterministicTeacherVoice`
  — pure offline generator that words the plan with **variation-without-
  randomness** (rotates phrasing by conversation position + intent, skips
  already-used phrasings → the teacher stops repeating), in the target
  language. `llm_pipeline.dart` `LlmPipeline.respond` = brain → intelligence →
  plan → prompt → voice → language policy (strict voice gate + immersion drop)
  → reply + advanced context. `llm_model_manager.dart` — pure lifecycle
  mirroring Piper/Whisper (absent/downloading/verifying/ready/failed/deleting/
  corrupt/versionMismatch; SHA-verified; upgrade path) over repository +
  downloader seams; interchangeable GGUF (tiny/small/medium/large abstract).
  `llm_isolate.dart` — serializable message contract for background-isolate
  inference (no streaming tokens, out of scope). Disk backing
  (`infrastructure/llm_downloader.dart`: prefs repo + `GgufModelDownloader`
  with resume + SHA-256 via the new `crypto` dep). Providers:
  `llmModelRepositoryProvider`, `llmModelManagerProvider`, `localLlmProvider`,
  `llmPipelineProvider`. Settings: `/llm-settings` (download/delete/size/
  version/type/context length/status), linked from Voice settings. 320 tests
  (+14: prompt builder determinism/policy/no-repeat/immersion, conversation
  context bounding, voice target-language + variation, pipeline respond +
  policy, model manager lifecycle incl. corrupt/versionMismatch, JSON
  round-trip), analyze clean, Android debug build green. HONEST SEAM: real
  on-device GGUF inference (llama.cpp binding + isolate load/generate) is the
  device-gated next step — the deterministic voice is the shipping generator
  today and words the plan fully offline; the tutor still uses DemoTutorModel by
  default (swapping `tutorModelProvider` to the LLM pipeline lands with the real
  model to avoid regressing verified flows). NOT device-verified.

- 2026-07-18: Phase 24 — Teacher Intelligence & Conversation Engine. Makes the
  AI decide like a real teacher, not a chatbot. `lib/language/teacher_intelligence.dart`
  (pure, deterministic, offline; consumes ONLY the Teacher Brain — no UI, no
  persistence, no learner state of its own): `TeacherIntelligenceEngine`
  decides WHAT to teach, WHY and WHEN (the pedagogy). Produces `TeacherDecision`,
  `TeacherResponsePlan`, `ConversationState` (lesson stage / objective / active
  concept / confidence / energy — all derived, no duplicate state),
  `TeachingMoment` (connection-first, often Socratic), `TeachingOpportunity`
  (ranked: recovery → active misconception → connection → mental-model
  discovery → curiosity), `CorrectionPlan` (ONE weak point, praise-first, why
  anchored to a family the learner already holds), `ConversationMemory` (real
  "Remember…" references from connections/history, never invented),
  `ReflectionPlan` (improved / needs-work / next / homework from measured
  trends). Encodes the core philosophy: **invisible teaching** (discovery
  moments show-and-ask rather than announce "today we learn X"), **Socratic
  guidance** ("what do these have in common?"), **connection-first** (every
  moment names the family / ties to known ground), **adaptive pacing**
  (slow-down / review / story / challenge / recover — from difficulty fit +
  motivation + profile, never random). A future local LLM (P25) will consume
  this to word responses naturally — it never decides pedagogy; this engine
  remains the teacher. Providers: `teacherIntelligenceProvider` +
  `teacherPlanProvider` (the next-turn plan, derived from the live brain).
  Light integration: the tutor now opens with a genuine memory reference when
  one exists (persistent-teacher feel), additive to the Phase 21 greeting.
  Nothing fabricated — empty/null when the brain lacks data. 306 tests (+14:
  lesson arc/pacing, conversation state, teaching decisions incl. recovery,
  Socratic discovery, connection-first moments, adaptive correction + none-when-
  clean, memory/reflection from real data, full-plan closing stage, determinism,
  empty-brain non-fabrication), analyze clean, Android debug build green.

- 2026-07-18: Phase 23 — Local Whisper architecture + speaking analytics
  (offline speech understanding). Piper gives offline speech OUT; this adds the
  offline speech-IN counterpart behind a clean seam. **Whisper subsystem**
  (`lib/language/whisper/`): `WhisperService` interface + `NoopWhisperService`
  (tests) + `FallbackWhisperService` (delegates to the platform recognizer,
  offline-capable — so speaking works today); `WhisperModelManager` — a pure,
  deterministic model lifecycle (absent → download w/ progress → verify →
  ready; stale-version invalidation; verify/delete) over a
  `WhisperModelRepository` + injected `ModelDownloader` seam; `whisper_isolate`
  message contract mirroring Piper's background-isolate design;
  `whisper_pipeline` orchestrating mic → transcript → analytics → feedback.
  Disk backing (`infrastructure/whisper_downloader.dart`:
  `PrefsWhisperModelRepository` + `HttpModelDownloader` with resume + isolate
  extract). **Speaking analytics** (`lib/language/speaking_session.dart`,
  pure): `analyzeSpeaking` turns any recognized utterance (Whisper or fallback)
  into a measured `SpeakingSession` — pronunciation (phoneme-aware),
  fluency (words/sec, null without duration), hesitation/filler counts, repair
  attempts, behavioural confidence (null when nothing said — never
  fabricated); `speakingOutcome` feeds the brain's lessonHistory;
  `connectionFeedback` praises by naming the family ("you used the same pattern
  as tener hambre, tener sueño…") so speaking reinforces the mental network,
  and returns null rather than invent a link. **Teacher Brain integration**:
  speaking sessions (via `speakingSessionsProvider`) now feed lesson outcomes
  alongside reading records — the speaking-practice attempt runs through the
  Whisper pipeline. **Settings**: `/whisper-settings` model screen (download /
  verify / delete / storage size), linked from Voice settings. The platform
  recognizer is now an explicit, labelled fallback. 292 tests (+14: model
  manager lifecycle/version/error/delete, speaking analytics + null-when-
  unmeasured, connection feedback present/absent, pipeline capture + fallback,
  feedback selection), analyze clean, Android debug build green. HONEST SEAM:
  real on-device sherpa-onnx `OfflineRecognizer` inference + raw-PCM mic
  capture (needs an audio-capture plugin + physical-device verification) is the
  documented next step — staged exactly as Piper's real synthesis was after
  its scaffold; the interface, model manager, pipeline and analytics are real
  and complete now, so only the `whisperServiceProvider` binding moves.

- 2026-07-18: Phase 22 — Phase15-FINAL merge + Learning Experience Engine.
  **Merge**: `origin/feature/phase15-premium-offline-voice-final` merged into
  the Phase 16–21 line — real Piper offline-neural TTS (sherpa_onnx,
  background-isolate inference with the device-verified ANR fix), the
  "La casa del faro" graded novel, story chapters, voice-settings download UI.
  Conflicts were docs/deps only (both dependency sets kept; both histories
  kept; lock regenerated); all newer architecture preserved. **Learning
  Experience Engine** (`lib/language/experience.dart`, pure): **vocabulary
  mining** (`mineVocabulary` — recurring words ranked, known/unknown judged
  from curriculum + the learner's actual mastery); **reading records**
  (`buildReadingRecord` — a finished story yields a measured record: known
  ratio as a comprehension proxy, unknown words, topics); **lesson outcomes**
  (`outcomesFromRecords` — the first real producer of the brain's
  `lessonHistory`); **interest discovery** (`discoverInterests` — weighted
  topics of books the learner actually chose and finished; empty history ⇒ no
  interests, nothing fabricated); **plain-text book import**
  (`importPlainText` — paragraphs→pages, sentence-boundary splitting;
  `BookImportParser` seam typed for PDF/EPUB backends). **Persistence**:
  `ExperienceRepository` seam + `PrefsExperienceRepository` (records capped,
  imported books, saved words) + in-memory test double. **Producers wired**:
  finishing a story in the reader records a reading session; the Teacher
  Brain now receives `interests` + `lessonHistory` from real reading records
  — two Phase 17–20 empty seams are now live. **Library**: "Import text"
  action (paste a passage → readable, narrated, mineable book on the shelf;
  dependency-free). 278 tests (+9: mining known/unknown + empty, record
  measurement, outcomes, weighted interests + none-fabricated, import
  chapterization, record JSON, prefs round-trip incl. restart), analyze
  clean, Android debug build green (sherpa_onnx/audioplayers integrate).

- 2026-07-18: Phase 21 — Unified Language Pipeline + persistent AI teacher.
  **Strict voice rule** (`lib/language/pipeline.dart`, pure): `speechSafeText`
  gates everything bound for TTS — sentence-level language detection (small
  deterministic function-word sets) keeps only target-language sentences, so
  **English never reaches the Spanish voice**; `splitTeacherReply` separates
  the spoken target body from native support text. **Immersion / Mentor
  modes** (`teacherSupportModeProvider` + session chip): mentor shows English
  support in italics under Spanish replies; immersion hides it — audio is
  Spanish in both. **Tutor bug fixes**: duplicate replies (root cause — the
  demo immersion strategy returned one fixed question every turn, and
  conversation beats clamped at the last beat; both now rotate with distinct,
  reacting, connection-referencing questions), a controller-level dedupe guard
  (never the identical tutor line twice in a row), and **input sanitization**
  (`sanitizeUserInput` strips control/escape artifacts like `\|Si` before the
  tutor sees the message). **Teacher personality**: sessions open with
  `teacherGreeting(brain)` — the brain's leading curiosity/observation (real
  data, never canned) as the teacher's first line. **Adaptive feedback**
  (`adaptiveFeedback`): scored-attempt phrasing that references connection
  moments and recovery state. **Dynamic speaking practice**: with no explicit
  focus, the speaking controller now asks the Teacher Brain — recently-active
  + not-yet-known concepts first, drill order rotated by streak day, so
  consecutive days practice different material (deterministic, no repeats).
  **Reader integration (first producer)**: every word in the story reader is
  long-pressable — `explainWord` teaches through connections first (known
  neighbour, related concepts, mental-model insight), dictionary translation
  second, and is honest ("we haven't met this word yet") for unknown words.
  Local-LLM seam unchanged and confirmed: reasoning stays behind
  `ReasoningEngine`/`AiChatModel`; prompts live outside UI. 268 tests (+11:
  voice gate/split, sanitization, immersion-variety regression, greeting-from-
  notebook, adaptive feedback, explainWord known/unknown), analyze clean,
  Android debug build green. NOTE: `origin/feature/phase15-premium-offline-
  voice-final` (real Piper + novella) appeared on the remote — not merged this
  phase (conflict risk on touched speech/tutor files); merge as its own task.

- 2026-07-18: Phase 20 — Learning Profile + Teaching Style Engine + Adaptive
  Pedagogy. The teacher now knows HOW the learner learns and adapts how it
  teaches — optimizing long-term learning over lesson completion.
  **LearningProfile** (`lib/language/learning_profile.dart`, pure): typed,
  explainable traits derived only from real data — core Learning DNA
  (repetition/fast/slow-durable/pressure/consistency/confidence), skill
  balances (strong listener/reader, speaking avoidance), each with evidence.
  Includes a **ConfidenceModel separate from mastery** (someone may understand
  grammar but avoid speaking — avoidance drags speaking confidence below its
  mastery) and a **MotivationModel** (flowing/steady/strained + momentum, from
  snapshot history and streak; unknown until ≥2 sessions). Learning speed and
  difficulty tolerance stay null under 10 answers — nothing fabricated. The
  profile is recomputed every brain build, so it evolves automatically.
  **TeachingStyleEngine** (`lib/language/teaching_style.dart`, pure): decides
  the presentation (example/story/conversation/review/challenge/encouragement/
  connection-first), correction style (minimal/gentle/detailed), and continuous
  **difficulty fit** (too easy/ideal/too difficult/unknown). **Recovery
  detection**: sustained mastery decline across recent snapshots, or
  too-difficult material, flips `recoveryMode` — review only, no new concepts —
  and this propagates into the unified teacher's choice (`teaching_planner`
  honors it first). **Success prediction** (`predictSuccess`): prerequisite-
  weighted probability before assigning a lesson (low → prerequisites first).
  **Readiness analytics** (`computeReadiness`, typed, architecture): speaking/
  reading/conversation readiness, retention, learning efficiency — real
  measurements only, null when unmeasured. **TeacherReflection** typed model
  added (producer lands with lesson outcomes in the roleplay phase). Brain now
  carries `profile`, `pedagogy`, `readiness`, `reflections`; `BrainInputs`
  gains full snapshot `history`. Everything derived from the brain,
  deterministic, offline; premium still swaps only ReasoningEngine. 257 tests
  (+14: profile derivation/avoidance/confidence-split/motivation/no-fabrication,
  style engine recovery/difficulty/profile-driven style, success prediction,
  readiness, brain integration + recovery propagation), analyze clean, Android
  debug build green.

- 2026-07-18: Phase 19 — Adaptive Lesson Generator + Curiosity Engine + Mental
  Model Builder. Three new pure/offline engines that make the Teacher Brain
  *proactively teach* instead of only measure. **Mental Model Builder**
  (`lib/language/mental_models.dart`): turns connection links into
  understanding — curated big-idea insights ("Spanish uses TENER where English
  uses TO BE", por↔movement-through / para↔direction-toward, ser/estar) plus
  generic family models, derived deterministically from the connection graph;
  `discoverPatterns` surfaces verb/grammar/semantic families and
  interference/false-friend/progression regularities. **Curiosity Engine**
  (`lib/language/curiosity.dart`): a few genuine, capped, priority-sorted
  observations the teacher volunteers ("this is the 3rd time this pattern has
  tripped you up", "you're holding back on speaking", "you've learned enough
  vocabulary to begin reading") — never spam, each fires only when its real
  condition is met; plus `buildConnectionMoments` for short "this works just
  like X" asides. **Adaptive Lesson Generator**
  (`lib/language/lesson_generator.dart`): consumes the brain and emits a typed
  `LessonPlan` — today/recovery/grammar/stretch/review/conversation/story/
  speaking recommendations following the Known → Connected → New → Practice →
  Reflection → Connection-review → Mental-model arc. The brain now carries
  `mentalModels`, `patterns`, `curiosities`, `connectionMoments`; the reasoning
  engine populates them and folds the top mental model + top curiosity into the
  notebook, so the dashboard shows the teacher teaching with no UI rewrite.
  Providers: `lessonPlanProvider` (the orchestrator's "what next", derived from
  the brain). Reading/speaking integration is architecture-only (recommendations
  live on the brain/plan; UI producers wire in later phases). Everything
  deterministic, offline, single-source-of-truth (all derived from the brain,
  no parallel stores); the existing daily-lesson engine is untouched (it feeds
  the brain). 243 tests (+10: mental models/patterns/no-fabrication, curiosity
  cap + repeated-pattern + moments, lesson-plan arc + recommendations, brain
  integration + notebook surfacing), analyze clean, Android debug build green.

- 2026-07-18: Phase 18 — Unified Adaptive Teacher + Connection Engine (teaching
  through connections). **Connection Engine** (`lib/language/connections.dart`,
  pure/offline): derives the learner's *personal* relationship graph from the
  existing curriculum knowledge graph + mastery — `ConnectionGraph` of
  `ConceptNode`s and typed `ConceptEdge`s (`ConnectionRelationType`), grouped
  into `LearningCluster`s, split into **strong** (both ends known), **weak**
  (shaky), and **hidden** connections (one end known, the other not yet met —
  the teaching frontier). From the hidden edges it builds ranked
  `ConnectionSuggestion`s ("you already know *tener hambre* — connect it to
  *tener sueño, tener miedo*"). Nothing new is stored; the graph is derived
  each build, so the Teacher Brain stays the single source of truth. Added to
  `TeacherBrain.connections`; notebook observations now carry `conceptIds` and
  a **connection note** is generated from the top suggestion; `explainByConnection`
  gives reading-tap the architecture to explain a word via a known neighbour
  instead of a definition (producer wires later). **Unified Teacher**
  (`lib/language/teaching_planner.dart`, `chooseTeachingStrategy`): the Teacher
  Brain now picks the strategy automatically (repair-through-connection → get a
  lagging speaker talking → build outward from a strong anchor → review). **The
  visible 6-mode selector is removed** from the tutor screen — replaced by one
  "Today's lesson" card that shows the teacher's chosen focus + rationale and
  starts directly. The six internal strategies are preserved (the teacher picks
  among them); `teachingChoiceProvider` exposes the decision. Deterministic and
  offline throughout; future relation producers (pronunciation patterns,
  collocations, word formation, …) are enum-typed but not emitted until real
  data backs them — no fabricated connections. 233 tests (+10: connection graph
  classification/suggestions/no-fabrication/explain, strategy selection, brain
  connection note), analyze clean, Android debug build green.

- 2026-07-18: Phase 17 (Teacher Brain) — elevate the notebook engine into the
  application's central **Teacher Brain**: one derived, structured source of
  truth about the learner that every future feature reads from. It is
  *assembled* from the app's existing authoritative captures (learner model,
  signals, misconceptions, Learning DNA, goals, persisted snapshots) — not a
  parallel store — so there is one truth and many consumers (no duplicate
  learner state). Cleanly separates **FACTS** (`LearnerFacts`: per-skill
  level/confidence/trend, grammar buckets mastered/learning/weak/locked,
  vocabulary + estimated known words, pronunciation, CEFR) from
  **OBSERVATIONS** (the notebook — teacher interpretations generated from those
  facts). Every observation now carries **evidence** and is explainable: tap a
  note on the dashboard to see the facts behind it (e.g. Listening 78% +11% vs
  Speaking 55%). New: `lib/language/teacher_brain.dart` (immutable model —
  identity with day-streak + estimated vocabulary, skills, grammar, vocabulary,
  pronunciation, objectives, lesson-outcome history, interests, Learning DNA;
  pure `computeStreak`) and `lib/language/reasoning_engine.dart` (the
  **`ReasoningEngine` interface** + deterministic offline `OfflineReasoningEngine`
  — the single premium swap point; a cloud engine replaces only this, leaving
  model/persistence/UI untouched). Providers: `reasoningEngineProvider` +
  `teacherBrainProvider` (replaces `teacherNotebookProvider`; assembles the
  brain from live state, writes today's snapshot). Offline-first throughout, no
  network. Sections without a data source yet (interests auto-discovery,
  per-phoneme pronunciation, writing skill, lesson outcomes) are typed but
  empty with capture seams — never fabricated. 223 tests (+9: engine facts,
  per-skill trend, grammar buckets, streak, estimated vocab, explainable-
  evidence), analyze clean, Android debug build green.

- 2026-07-18: Phase 17 — Teacher's Notebook engine (real + persistent; the
  app's first cross-session memory). Replaces the Phase 16 placeholder notes
  with observations generated **live** from the learner's own metrics, in a
  teacher's voice — nothing is fabricated: a note only appears when its signal
  has actually been measured. `lib/language/notebook.dart` (pure, deterministic
  `buildTeacherNotebook`) derives: recurring grammar mistakes (named from the
  concept graph, with occurrence counts), vocabulary mastery vs the working
  level, strongest/weakest skills, listening-vs-speaking balance, pronunciation
  confidence, a **session-over-session trend** (up / steady / slipped), a
  coarse **CEFR estimate** ("around A1"), and the **next lesson** from the plan.
  **Persistence:** `TeacherNotebookRepository` seam
  (`lib/language/notebook_repository.dart`) with an in-memory default and a
  `shared_preferences` disk adapter
  (`lib/infrastructure/prefs_notebook_repository.dart`) — one metrics snapshot
  per day, capped, so trends compare against a prior day. Adds the
  `shared_preferences` dependency (first real on-disk persistence; offline, no
  account). Providers: `teacherNotebookProvider` (FutureProvider building the
  live notebook + writing today's snapshot) and
  `teacherNotebookRepositoryProvider` (swap point for Firestore later). The
  dashboard's Teacher's Notes card renders the live notebook (category icons,
  working-level header, plan lines highlighted); the tappable misconception
  card remains below it. 214 tests (11 new: engine, trend, CEFR, snapshot
  JSON, merge/cap, in-memory + prefs round-trip), analyze clean, Android debug
  build green.

- 2026-07-18: Phase 16 — Lab home redesign (dashboard only; tutor, Piper,
  Whisper, and the AI/adaptive engine untouched). The home now reads as
  "my teacher knows me" instead of a wall of launch cards. **Removed the
  large Reading / Speaking / Conversation cards from the dashboard** — the
  features are unchanged and still reached from the bottom navigation
  (Library / Speaking / Tutor). The dashboard is rebuilt around five
  teacher-focused sections: **Teacher's Notes** (a persistent notebook,
  placeholder-sourced via the new `teacherNotesProvider` swap point, with the
  live misconception card folded in), **Today's Goals** (Reading / Listening
  / Speaking / Conversation daily progress bars), **Progress summary**
  (per-skill mastery, no XP), **Current focus** (the active lesson named for
  the learner, with estimate + remaining activities, over the live plan), and
  **Recommended next lesson** (one pick from today's plan). Dashboard widget
  tests updated to the new layout; all 203 tests pass, analyze clean, Android
  debug build green.
- 2026-07-17: Phase 15 final — **real Piper offline-neural TTS + flagship
  graded novel**. Piper now actually speaks: `PiperSpeechService` runs
  Piper VITS voices on-device through sherpa_onnx (ONNX runtime; free,
  open source, no API keys). The es-ES voice model
  (`vits-piper-es_ES-davefx-medium`, 63 MB ONNX + espeak-ng data) is
  downloaded on first use from the sherpa-onnx releases (progress bar in
  Voice Settings), extracted (pure-Dart tar.bz2) and cached in app
  documents — never bundled in git. Sentence-chunked synthesis → WAV →
  audioplayers playback, with generation-token cancellation for instant
  barge-in. Piper is the DEFAULT engine; device TTS remains a selectable
  fallback in Voice Settings (learner's choice — never a silent
  substitute). Verified on emulator via logcat: model downloaded
  (63,149,192 bytes on device), `[PIPER] gen#4 chunk0 samples=39680
  sr=22050` synthesis lines, chunk gaps matching audio duration
  (playback), "Piper voice ready" status card. **Flagship novel:** "La
  casa del faro" — an original graded A2 novella (7 chapters, 42 pages,
  ~2,700 Spanish words + full English translation): recurring characters
  (María, Don Andrés, Lucía), natural dialogue, chapter cliffhangers, an
  emotional arc, optional end-of-book quiz. `Story` gains chapters
  (`chapterTitles`/`chapterStarts`, pages flow continuously — reading is
  never interrupted; completion card only after the final page); the
  reader shows a "Capítulo N · title" header; library cards show chapter
  counts. Verified on device: library card "17 min · 7 chapters", reader
  at 1/42 with the chapter header and Piper narration playing. 204 tests
  green.

- 2026-07-17: Phase 15 — premium-voice architecture + immersive reading UX
  (UX only; core/providers-of-record untouched). **Speech-engine selection**
  behind the seam: `speechEngineProvider` picks Piper (offline neural,
  default) or the device engine; the UI never depends on which. **Piper is
  a labeled SCAFFOLD** (`PiperSpeechService`) — it implements the seam and
  reports `SpeechEngine.piper` but delegates audio to the platform engine
  until a Piper binary + ONNX model are bundled (native work, not shipped
  here). **Voice Settings** screen (`/voice-settings`, from the tutor):
  engine picker + speech-speed 0.8×–1.2×, held in session providers; a new
  `speed` seam param scales the base rate so **rate is never hard-coded**.
  **Reading flow:** the mandatory post-chapter quiz is gone — finishing a
  chapter shows a **completion card** (Continue reading · Reading companion
  · Vocabulary review · Speaking practice · optional quiz); reading is never
  interrupted. **Reading Companion** bottom sheet — ask about the current
  page without leaving the book (quick chips + free text), answered via the
  existing `AiChatModel` seam. **Library:** added a **Bookmarks** shelf.
  203 tests green.

### Fixed

- 2026-07-17: Phase 14b — voice debug + acceptance (device-traced, no
  guessing). **Engine (traced at runtime):** `flutter_tts` 4.2.0 +
  `speech_to_text` 7.0.0 → Android `com.google.android.tts` (Google TTS).
  Voice was `es-us-x-sfb-network` (Latin-American) for an `es-ES` request —
  the picker preferred any "network" voice over locale. **Fixed:** now
  prefers the exact locale first, so `es-ES` speaks Castilian
  (`es-es-x-eec-network`), verified on device. Rate 0.42 (tutor)/0.44
  (reader), pitch 1.06. **Spoken-string logging:** every `speak()` now
  logs the exact synthesizer input in debug builds; confirmed it contains
  no markdown/`**`/URLs/emoji/bullets (commas remain, as pauses — never
  vocalized). Collapsed leftover `..` double-periods from paragraph joins.
  **Barge-in verified via logcat:** `speak() gen=3` → mic press
  `stop() → gen=4` → the clause loop aborts (3≠4) → speech halts, listening
  begins. **Honest:** the Google on-device voice is decent but not
  ChatGPT/ElevenLabs neural quality — premium voices require binding a
  cloud neural provider (Google Neural2/WaveNet, Azure Neural, ElevenLabs,
  OpenAI TTS) behind the existing `SpeechEngine` seam (one `speechService`
  binding + keys, no UI change). 203 tests green.

- 2026-07-17: Phase 14 — bug fixes + UX completion (verified on device).
  **Barge-in bug** (real): `PlatformSpeechService.speak` speaks clause by
  clause; `stop()` killed only the current clause and the loop kept going,
  so the tutor talked on after the mic was pressed. Added a generation
  token — `stop()`/`pause()` bump it and the loop aborts before the next
  clause, so a barge-in cancels the whole utterance. **Voice**: engine is
  `flutter_tts` (Android → the device Google/Samsung TTS voice); added
  stripping of bare **URLs and emails** to `spokenText` (markdown, bullets,
  emoji, dashes, ellipses were already stripped). **Reading Library** is now
  a real book library — horizontal shelves (Continue reading · Spanish
  classics · Beginner · Intermediate) of cover cards showing level, author,
  reading time, chapter count and in-session progress. **Reader** resumes
  from the last page read and keeps session bookmarks (new in-memory
  `reading_state`; a reactive `readingRevision` refreshes the Continue-
  reading shelf). **Keyboard**: confirmed the floating pill is **Gboard's
  floating-keyboard mode** (system keyboard), not app UI — the app's inputs
  are normal bottom fields; not app-fixable. 202 tests green.

### Added

- 2026-07-17: Phase 13 — conversational AI + Kindle-style reading (UX only;
  no providers/core). **Voice conversation state machine** in the tutor:
  Idle → Listening → Processing → Speaking → Error, shown as a live status
  pill; the mic is now **press-and-hold** (hold to talk, release to send)
  with **barge-in** — pressing it cuts off the AI's speech instantly and
  returns to Listening (ChatGPT-Voice feel). **Speech-engine abstraction**:
  a `SpeechEngine` descriptor on the `SpeechService` seam (Demo / Android
  Neural / iOS Enhanced / Cloud) so a neural/cloud provider can be swapped
  in with no UI changes. **Reader** gains a Kindle-style Español / Both /
  English display toggle (translation stays secondary) and a bookmark
  action. **Home** adds collapsed Speaking and Conversation sections with
  one-tap launchers. **Library** cards show the author and an estimated
  reading time; added `Story.author` + `readingMinutes`. 201 tests green;
  emulator-verified (reader toggle, Listening state) light + dark.

### Changed

- 2026-07-17: Phase 12 (premium UX) — home, reading, voice (UX only; no
  providers/core touched). Warm light theme: pure-white surfaces shifted to
  soft warm grays (calmer for long reading). **Compact dashboard**: a
  greeting header with language + CEFR pills + a "Continue learning"
  button, then collapsible sections — Today's plan (open by default),
  Skill mastery, Teacher notes and a new Reading recommendation (collapsed,
  smooth ExpansionTile animation) — so the home scans at a glance. Story
  reader gains a full **audiobook player** (play / pause / stop / previous
  / next paragraph + 0.8×/1.0×/1.2×/1.5× speed; Stop always halts at once;
  audio stops on page turn). Tutor mic now **barges in** — tapping it cuts
  off the AI's speech immediately. Reading Library: Stories renamed to
  "Reading Library" (nav + screen), plus a new public-domain classic
  (Lazarillo de Tormes, B1) with glossary + quiz. Speech seam gains a
  best-effort `pause()`. 201 tests green; emulator-verified light + dark.

- 2026-07-17: Phase 11 — experience overhaul (UX only; core/providers
  untouched). Stories rewritten as real multi-sentence **narratives**
  (3–4 sentence pages instead of one-line phrases) across all ES stories.
  Story reader **redesigned**: a swipeable `PageView` (smooth page
  transitions), large book-like target text, the translation demoted to
  secondary muted body text, a slim animated progress bar with an "n / N"
  counter, and generous negative space over the atmospheric backdrop
  (fewer heavy containers). Voice: `spokenText` now also strips bullet
  glyphs and emoji, and TTS reads slightly slower with longer clause
  breaths for a warmer, less robotic delivery. Speaking feedback rewritten
  as warm coaching lines by score band with a count-up score animation.
  Tutor chat bubbles get more breathing room. Motion added: reader page
  transitions, animated reading progress, speaking score count-up (on top
  of the existing entrance fades). 201 tests green; emulator-verified in
  light + dark.

- 2026-07-17: Phase 12 — classic stories, quiz, voice + Stories usability.
  Three famous public-domain tales adapted as graded readers (A1 fable
  "La liebre y la tortuga", A2 legend "La leyenda de la Llorona", B1
  "Don Quijote y los molinos de viento"), each with a key-words glossary
  and a comprehension quiz. `Story` gains optional `vocabulary` +
  `questions` (parsed from the stories JSON; legacy stories unaffected).
  The reader adds a Key-words bottom sheet and an end-of-story quiz
  (per-question correct/incorrect colouring + running score). Stories are
  grouped under CEFR-level section headers with a Quiz badge on cards.
  Voice: `spokenText` now turns em/en dashes (Spanish dialogue) and
  ellipses into natural pauses instead of speaking them. 3 new tests
  (201 green). Emulator-verified end to end.

- 2026-07-17: Phase 10 — first-run onboarding + Hume-inspired visual
  maturity (UI only). New immersive onboarding flow (`/onboarding`,
  gated by `onboardingSeenProvider`): a 3-step atmospheric PageView
  (welcome → pick target language → set daily minutes + target CEFR level)
  writing the same `selectedLanguage`/`learnerGoals` providers the Lab
  uses, with a segmented progress bar and a full-width CTA. UI kit gains
  `AtmosphericBackground` (dark-first gradient + soft colour glows),
  `GlassCard` (frosted translucent surface with a backdrop blur + hairline
  border) and `_fadeThrough` shared-axis route transitions. Applied
  atmospheric backdrops across Lab / Tutor / Stories / Speaking / Story
  reader, glass cards on the plan + skill-mastery cards and the onboarding
  steps. 1 new onboarding widget test (199 green); dark-mode verified.

### Changed

- 2026-07-17: Phase 9 — deeper premium redesign + consistency (UI only, no
  logic/core changes). New shared UI kit `presentation/ui.dart`: a 4-based
  spacing scale (`AppSpace`), radius/motion tokens, a reusable `GradientHero`
  (soft shadow + top-left glass sheen — dedupes the dashboard/tutor heroes),
  a frosted `GlassPill`, and a `FadeInUp` entrance (staggered via curve
  interval, no timers). Applied across the dashboard (staggered section
  entrances, hero depth), tutor mode grid + hero + chat bubbles, stories
  (gradient leading tiles, cascade in), speaking intro (gradient halo icon)
  and the story reader (per-phrase fade). Theme: cards gain a faint shadow
  with no surface tint for clean depth; consistent card/input radii.
  Full dark-mode audit on the emulator — all surfaces adapt via scheme
  roles, no regressions. 198 tests still green; analyze clean.

- 2026-07-17: UX polish — the AI-tutor chat renders `**bold**`/`*italic*`
  markdown as real emphasis instead of literal asterisks; the tutor reply
  and practice text fields drop the Flutter floating selection toolbar
  (`contextMenuBuilder` → empty) and use the premium filled input; sending
  a reply unfocuses the field so the keyboard dismisses cleanly. Refined
  app-wide typography (tighter headings, roomier body line-height) and a
  soft bubble shadow. Voice: `spokenText` normalizes markdown before TTS
  so the engine never voices `*`, `` ` `` or heading/list markers, in
  Spanish and English (Spanish `¿¡?!` kept for prosody); 3 new tests
  (198 green). Note: Gboard's own floating-keyboard toolbar is a device
  keyboard mode, outside app control.

### Fixed

- 2026-07-16: Android `applicationId` → `com.adaptiveexam.adaptive_language_platform` and iOS bundle id → `com.adaptiveexam.adaptiveLanguagePlatform` (inherited exam-platform ids made emulator installs silently replace the exam app; both apps now verified side by side on one device). Kotlin namespace/MainActivity package left for the queued package-rename sweep.

### Added

- 2026-07-17: Phase 8 — Production readiness demo slice (ADR-0026): approved Content-Studio candidates merge into the live curriculum via `mergeApprovedContent` (`lib/language/content_merge.dart`) — unmapped vocabulary/phrases/idioms become new concept/phrase nodes under a synthesized `<lang>:<level>:vocabulary:ingested` domain that generates exercises and projects onto the core unchanged, and `storyFromApproved` turns approved sentences into a story; a durable `approvedContentProvider` (appended on approve, cleared on reject, reset on language switch) is watched by `curriculumProvider` and `storiesProvider` so ingested material surfaces in practice, stories and the plan immediately, with the review queue still the only gate; learner goals (`learnerGoalsProvider`: minutes/day + target CEFR level) now drive `availableMinutesProvider` (lesson time budget), the story-queue level cap and the tutor goal string, set from a new `/goals` screen; `PRODUCTION_CHECKLIST.md` tracks the remaining launch work. 9 new tests (195 green). Core + seams untouched.

- 2026-07-17: Phase 7 — Content ingestion (ADR-0025): `ingestLanguageText` extracts review candidates (vocabulary, phrases, example sentences, idioms, cultural notes) with estimated CEFR difficulty and topics from pasted target-language text, mapping each to a curriculum concept id where recognized; `ContentReviewLog` + repository seam for a human approve/reject queue; admin-gated Content Studio (`/content`, Lab app-bar entry) to paste/sample → extract → review. Input cleanup: practice unfocuses on submit/advance so the system keyboard never lingers. Four new narrative stories (2×A1, 2×A2). 10 new tests (186 green). Core + seams untouched.

- 2026-07-17: Phase 6 — Speech & Pronunciation depth (ADR-0024): phoneme-aware pronunciation scoring (`scorePronunciationDetailed`) with per-word alignment, normalized edit distance over phonetically-folded forms, partial credit for near misses and per-word ✓/✗ feedback; listening-recognition exercise (`ExerciseType.listening`, hidden spoken audio + pick-the-word) with a new `listeningRecognition` signal; `pronunciationConfidence` and `conversationAbility` now weight the daily lesson's speaking/conversation blocks; per-language prosodic TTS (clause chunking, punctuation-sized breaths, question rise/slow); premium UI pass (pill NavigationBar with select-only labels, flat app bars, rounded filled buttons + inputs). 13 new tests (176 green). Core + speech seam untouched.

- 2026-07-17: Phase 5 — Conversation Engine + voice naturalness (ADR-0023): scenario-driven multi-turn dialogue for Conversation and Immersion modes — `TutorContext` carries the scenario and weak-concept target vocabulary, `pickScenarioConceptId` weights toward weak concepts, and the tutor reacts to the learner's last message, recasts errors in-reply, weaves target vocab, progresses the scene and ends with a follow-up; `conversationAbility` signal (`afterConversationTurn` + `conversationTurnQuality`) recorded per learner turn; Conversation plan block launches a Conversation session; enriched scenario data; DemoTutorModel rewritten for contextual multi-turn replies. Voice: sentence-chunked prosodic TTS (breaths between clauses, question-pitch lift, full volume, warmer defaults). 11 new tests (165 green). Core untouched.

- 2026-07-17: Phase 4 — Daily Personalized Lesson Engine (ADR-0022): `buildDailyLesson` replaces the preview heuristics with weighted, time-budgeted blocks assembled from misconception repair (first), spaced-repetition due concepts, weakest skills, low pronunciation confidence, a concept-overlapping story and a conversation tail; Learning DNA traits shape the block weights and count; each block carries a plain-language reason and a launchable activity (practice/speaking/story/tutor); tappable Today's-Plan blocks dispatch to the right screen. Enriched narrative stories with larger readable phrase chunks. Warmer, more natural TTS (rate/pitch params + enhanced-voice selection). 8 new tests (155 green). Core untouched.

- 2026-07-16: Content & Voice — stories, speaking, tutor voice, bottom-nav shell (ADR-0020/0021): short stories as data (`lib/language/story.dart` + `assets/stories/`) with a level-matched phrase-by-phrase reader (target + translation, per-phrase and whole-story text-to-speech) and a Today's-Plan recommendation; speaking practice (`lib/language/speaking.dart`) with graph-derived drills, accent-folded token-overlap pronunciation scoring feeding `pronunciationConfidence` plus a real core AnswerEvent, hear-target TTS and tap-to-speak mic; tutor voice — speak-aloud bubbles, "Voice replies" auto-speak toggle, mic dictation; provider-blind speech seam (`SpeechService` + flutter_tts/speech_to_text adapter, NoopSpeechService for tests, `available` guard); bottom `NavigationBar` shell (Lab/Stories/Speaking/Tutor) replacing the floating action button; Android `RECORD_AUDIO` permission; 10 new tests (147 green).

- 2026-07-16: Phase 3 dialogue depth (ADR-0018 addendum): per-mode dialogue plans (`Session flow:`) and `MODE:` tag in tutor prompts; DemoTutorModel composes six mode-true strategies (Teacher lesson with comprehension check, Conversation scenario turns, Coach minute-plans from live skill mastery, Socratic question chains, Grammar minimal pairs, Immersion target-language-only) with multi-turn awareness; immersion language-purity validation via native-stopword gate; Learning DNA traits recomputed after every answer and fed into TutorContext; tutor UI typing indicator + avatar chat bubbles; Today's Plan blocks launch focused practice on tap; exercise sessions interleave types; Android emulator verification with screenshots; 5 new tests (137 green).

- 2026-07-16: Product rebrand — language-first navigation + immersion UI (ADR-0019): Language Lab home at `/`, exam routes retired from navigation, multi-language selector (Spanish/English registries + per-language demo seeds, fresh learner state per switch — cross-language contamination found by adversarial review and fixed with regression tests), teal immersion Material 3 theme with gradient/tutor hero cards and AI Tutor FAB, Today's-plan-first dashboard, rebranded login/settings/web manifest, curriculum-derived tutor goals; 132 tests green.

- 2026-07-16: Phase 3 foundation — AI tutor (ADR-0018): `TutorContext` assembled per session from real learner state (skill mastery, weakest concepts, misconceptions, signals, goals, Learning DNA, focus-concept graph slice); six tutor mode contracts (Teacher/Conversation/Coach/Socratic/Grammar/Immersion) with distinct personas over serialized learner context; output validation gate (structure + focus-concept grounding, rejected output never shown); provider-blind `LanguageTutor` over the `AiChatModel` seam with `DemoTutorModel` for offline live demo (misconception repair first, pattern family second); `/language/tutor` mode selector + chat session UI and dashboard CTA; 11 new tests (131 green).

- 2026-07-16: Phase 2 finish — text-first exercise flows (ADR-0017): exercises derived from curriculum data (multiple choice, fill-in-blank, translation, sentence building, reading comprehension; deterministic seeded generation; repair concepts first; diacritic-preserving answer checks); `/language/practice` session screen with animated progress, inline teacher notes from the misconception engine and score summary; misconception detection now walks the concept lineage (child-exercise errors implicate ancestor grammar concepts); `recordAnswer` returns detections and awaits init; dashboard "Practice your weak spots" CTA; three new seed example sentences; 10 new tests (120 green).

- 2026-07-16: Phase 2 core — misconception engine + language signal tracking + Language Lab UI (ADR-0016): graph-authorized misconception detection (interferesWith/falseFriend relations + transfer traps) recorded separately from mistakes with explanations and pattern families; EWMA signal updates from answer events (recall difficulty/speed, usage frequency, grammar-transfer errors, native interference) beside the unchanged core LearnerModel; persistence seams with in-memory demo implementations; core LearnerEngine reused unchanged via the language graph projection; `/language` dashboard (animated per-skill mastery, Teacher Notes, repair-first lesson preview) and `/language/concept/:id` detail (signals, relations, live simulate); app title → Adaptive Language Platform; 11 new tests (110 green).

- 2026-07-16: Phase 1 — language domain model (ADR-0015): `lib/language/` pure-Dart layer with 11-tier knowledge hierarchy (typed grammar/vocabulary/phrase/example/exercise/conversation nodes, CEFR levels, 10 skills), `LanguageKnowledgeGraph` with typed relations (requires/buildsOn/interferesWith/culturalContext/falseFriend/relatedTo) projected onto the unchanged core graph, language memory signals + per-skill mastery aggregation, CEFR curriculum JSON schema/loader with Spanish-for-English and English-for-Spanish seeds, Firestore schema drafts (`docs/database/05-language-schema.md`); 10 new tests, 99 total green, core untouched.

- 2026-07-12: Phase 0 — repository forked from `adaptive-exam-platform` with full history (ADR-0014); product identity rewritten for the Adaptive Language Platform (README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG); roadmap defined (Phases 0–8: language domain model → adaptive tracking → AI tutor → daily lessons → conversation → speech → content ingestion → production).
