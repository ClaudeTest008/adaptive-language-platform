# Changelog

All notable changes to the Adaptive Language Platform are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Changes before 2026-07-12 belong to the exam-platform lineage; see git history and the original `adaptive-exam-platform` repository.

## [Unreleased]

### Fixed

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
