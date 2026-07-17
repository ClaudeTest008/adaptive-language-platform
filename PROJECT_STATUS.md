# Project Status

**Phase:** Phase 8 — Production Readiness (demo-mode slice complete; Firebase infra remaining)
**Last updated:** 2026-07-17

## Completed

- Phase 8 — Production Readiness demo slice (2026-07-17, ADR-0026):
  - Ingestion loop closed: `lib/language/content_merge.dart` `mergeApprovedContent` attaches approved, unmapped vocabulary/phrases/idioms as new concept/phrase nodes under a synthesized `<lang>:<level>:vocabulary:ingested` domain — they generate exercises like any authored node and project onto the core unchanged; `storyFromApproved` turns approved sentences into a "From your content" story. Base curriculum never mutated.
  - `approvedContentProvider` (durable, resets on language switch): Content Studio appends on approve / removes on reject; `curriculumProvider` and `storiesProvider` watch it, so approved items surface in practice, stories and the plan immediately. Review queue stays the only gate.
  - Learner goals (`learnerGoalsProvider`: minutes/day + target CEFR level, in-memory): `availableMinutesProvider` reads the goal (Daily Lesson Engine budgets to it), `storiesProvider` caps at the target level, tutor goal string reflects it. `/goals` screen (minutes slider + level chips) reachable from the Lab app bar.
  - `PRODUCTION_CHECKLIST.md` — pre-launch tracker (persistence swap, real speech/AI providers, iOS parity, analytics).
  - Verified: `flutter analyze` clean; 195 tests green (9 new); Android emulator — set goals (25→50 min) re-budgets Today's plan to 50 min; target level surfaces A2 stories.

- Phase 7 — Content Ingestion + input cleanup (2026-07-17, ADR-0025):
  - Language content extractor (`lib/language/ingestion.dart`): pasted target-language text → review candidates (vocabulary, phrases, example sentences, idioms, cultural notes) + CEFR difficulty + topics, mapped to curriculum concept ids where recognized. Deterministic.
  - Human review queue (`ContentReviewLog` + repository seam, in-memory demo) — approve/reject; nothing enters the curriculum unreviewed.
  - Admin Content Studio (`/content`, gated by `authState.isAdmin`, reachable from the Lab app bar): paste or "Use sample" → extract → preview grouped by kind with mapped/new status and per-candidate approve/reject.
  - Input cleanup: practice unfocuses on submit and on advancing, so the system keyboard never lingers as a "floating bar"; it reopens only on field tap. Voice/mic already bottom-docked.
  - Four new narrative stories (2×A1, 2×A2: market, park, morning train, birthday fiesta).
  - Verified: `flutter analyze` clean; 186 tests green (10 new); Android emulator — Content Studio extracts 34 candidates (A1, topics, vocab + phrases with review actions) from the sample passage.

- Phase 6 — Speech & Pronunciation depth + premium UI (2026-07-17, ADR-0024):
  - Phoneme-aware pronunciation scoring (`scorePronunciationDetailed`): per-word alignment + normalized edit distance over phonetically-folded forms (silent h, b/v, y/ll, qu/k, z/c→s, accents); near misses get partial credit; per-word ✓/✗ feedback in the speaking screen.
  - Listening recognition exercise (`ExerciseType.listening`): hear a spoken word (hidden audio), pick which word it was; auto-plays + "Play again"; new `listeningRecognition` signal via `recordAnswer(listening: true)`.
  - `pronunciationConfidence` + `conversationAbility` now weight the daily lesson — speaking/conversation blocks grow when those signals are low.
  - Voice: per-language prosody, clause-level chunking with punctuation-sized breaths, question rise/slow + exclamation lift.
  - Premium UI: pill NavigationBar with select-only labels, flat app bars, rounded filled buttons + filled inputs; no floating elements; keyboard only on field focus.
  - Verified: `flutter analyze` clean; 176 tests green (13 new); Android emulator — premium nav + cards, plan intact, speaking drill with prosodic TTS.

- Phase 5 — Conversation Engine + voice naturalness (2026-07-17, ADR-0023):
  - Scenario-driven multi-turn dialogue for Conversation + Immersion: `TutorContext` carries scenario + weak-concept `targetVocab`; `pickScenarioConceptId` weights scenarios toward weak concepts; the tutor reacts to the learner's last message, recasts errors in-reply (e.g. soy cansado → tengo sueño), weaves target vocab, progresses the scene, ends with a follow-up.
  - `conversationAbility` signal: `afterConversationTurn` EWMA + `conversationTurnQuality` (length + target-vocab use); recorded per learner turn on the scenario concept (signal-only; core untouched).
  - Wired: Conversation plan block launches a Conversation session; DemoTutorModel rewritten for contextual multi-turn replies; enriched scenario data ("At the café", "Making plans", "At the meetup").
  - Voice: sentence-chunked speech with breaths, question-pitch lift, full volume, warmer defaults, on top of enhanced-voice selection.
  - Verified: `flutter analyze` clean; 165 tests green (11 new); Android emulator — Conversation opened with weak-weighted scenario + vocab, gentle recast of a live "soy cansado" turn.

- Phase 4 — Daily Personalized Lesson Engine + content/voice polish (2026-07-17, ADR-0022):
  - `buildDailyLesson` replaces the preview heuristics: weighted, time-budgeted blocks from misconception repair (first), spaced-repetition due concepts, weakest skills, low pronunciation confidence, a concept-overlapping story, and a conversation tail. Learning DNA traits shape the weights (repeatsMistakes→repair, benefitsFromRepetition→review, strugglesUnderTimePressure→fewer/longer). Each block carries a plain-language reason + a launchable `LessonActivity`.
  - Tappable Today's-Plan blocks launch the right activity (practice / Speaking tab drill / story reader / Tutor tab). Engine stays pure — provider computes due concepts from core `ConceptStats`; core untouched.
  - Enriched stories: narrative mini-adventures ("El secreto del camarero", "La mañana de Pedro", "The first hello") with larger readable phrase chunks (≥6 words) and dual display.
  - Warmer TTS: SpeechService gains rate/pitch params; the adapter picks an enhanced/neural voice per language and uses a warmer default rate/pitch.
  - Verified: `flutter analyze` clean; 155 tests green (8 new lesson-engine + enriched-story tests); Android emulator run.

- Content & Voice — stories, speaking, tutor voice, nav shell (2026-07-16, ADR-0020/0021):
  - Short Stories: `lib/language/story.dart` + `assets/stories/` seeds (level-matched, phrase-by-phrase reader with target/translation + per-phrase and whole-story text-to-speech); Stories tab; Today's-Plan story recommendation.
  - Speaking practice: `lib/language/speaking.dart` (graph-derived drills, accent-folded token-overlap scoring); hear-the-target TTS, tap-to-speak mic, score → `pronunciationConfidence` signal + a real core AnswerEvent (mastery/DNA move); Speaking tab.
  - Tutor voice: speak-aloud on every tutor bubble, "Voice replies" auto-speak toggle, mic dictation into the reply field — same modes, now audible.
  - Speech seam: `lib/language/speech.dart` (`SpeechService`) + `infrastructure/platform_speech_service.dart` (flutter_tts + speech_to_text, best-effort); `NoopSpeechService` for tests; `available` guards voice UI on unsupported platforms.
  - UI: bottom `NavigationBar` shell (Lab / Stories / Speaking / Tutor) replaces the floating action button; keyboard shows only on field focus.
  - Verified: `flutter analyze` clean; 147 tests green (10 new content/speaking/controller tests); Android `RECORD_AUDIO` permission + recognizer query added.

- Phase 3 dialogue depth + Android verification (2026-07-16, ADR-0018 addendum):
  - Per-mode dialogue plans in every tutor prompt (`Session flow:` + `MODE:` tag); DemoTutorModel now composes six mode-true strategies (Teacher lesson w/ check question, Conversation scenario turns, Coach minute-plans from real skill percentages, Socratic single-question chains, Grammar minimal pairs, Immersion target-language-only), multi-turn aware.
  - Immersion language-purity validation: native-stopword gate in `validateTutorReply` (≥2 distinct native function words → rejected).
  - Learning DNA live: traits recomputed by the core engine after every answer, fed into every TutorContext.
  - UI: typing indicator (pulsing dots), avatar chat bubbles with asymmetric corners; Today's Plan blocks tappable (launch focused practice); exercise sessions interleave types.
  - Verified: `flutter analyze` clean; 137 tests green (5 new); **Android emulator run verified with screenshots** — login, Language Lab, tutor mode selector, live Teacher session with misconception repair all rendering the teal theme correctly on 1080×2400 (incl. dark mode).

- Product rebrand — language-first navigation + immersion UI (2026-07-16, ADR-0019):
  - Language Lab is now the app home (`/`); exam-era routes (practice/mock/bookmarks/search/admin) retired from navigation; login/settings/web manifest/index rebranded — no exam-flavored surface reachable (verified by adversarial sweep).
  - Multi-language selector (`availableLanguages` registry + `selectedLanguageProvider`): Spanish 🇪🇸 / English 🇬🇧, per-language demo seeds; fresh learner state per switch (review found + fixed cross-language contamination and count inflation; regression-tested round trip).
  - Immersion theme: teal M3 palette, gradient hero + tutor hero cards, frosted pills, rounded cards, AI Tutor FAB; dashboard reordered — tutor hero, Today's plan, practice CTA, skill mastery, teacher notes.
  - Tutor goals now derive from the selected curriculum ("Reach A2 {language}").
  - Verified: `flutter analyze` clean; 132 tests green; web boots cleanly, zero console errors.

- Phase 3 foundation — AI tutor (2026-07-16, ADR-0018):
  - `lib/language/tutor.dart`: `TutorContext` snapshot assembly (skill mastery, weakest concepts, misconceptions, signals, goals, Learning DNA, focus-concept graph slice with relations + pattern family); six mode contracts with distinct personas; `tutorSystemPrompt` serializes learner context; `validateTutorReply` gates every output (structure + grounding), rejected output replaced by safe fallback.
  - Provider-blind: `LanguageTutor` consumes any `AiChatModel` (`lib/ai/` untouched); `tutorModelProvider` = vendor swap point; `DemoTutorModel` composes deterministic teacherly replies from the same prompts a vendor would get (Teacher-mode live flow: misconception repair first, then pattern family).
  - UI: `/language/tutor` — gradient hero with live learner stats, six-mode grid, chat session with context chips (mode, focus, misconception count); AI Tutor CTA beside practice on the Language Lab dashboard.
  - Verified: `flutter analyze` clean; 131 tests green (11 new: context assembly, mode prompts, validation, tutor service, demo flow, widget); web boots cleanly.

- Phase 2 finish — text-first exercise flows + demo readiness (2026-07-16, ADR-0017):
  - Exercise generation derived from curriculum data (`lib/language/exercises.dart`): multiple choice, fill-in-blank, translation, sentence building, reading comprehension; deterministic (seeded shuffles); repair concepts sort first; diacritic-preserving answer checks.
  - `/language/practice` session screen: animated progress, per-type inputs (option cards, text field, word-bank chips), inline feedback with teacher notes from the misconception engine, animated score summary. Dashboard "Practice your weak spots" CTA (focused on the repair block).
  - `recordAnswer` returns detected misconceptions (inline feedback), awaits controller init (cold deep links safe), detects over the concept lineage — an error on "Tengo hambre" implicates `tener-states` — and registers transfer signals on the attributed ancestor.
  - Seed curricula gained three example sentences (data-only) to enrich the exercise pool.
  - Verified: `flutter analyze` clean; 120 tests green (10 new); web app boots cleanly (`flutter run -d web-server`, zero console errors, title "Adaptive Language Platform").

- Phase 2 core — misconception engine + signal tracking + Language Lab UI (2026-07-16, ADR-0016):
  - Misconception engine: graph-authorized detection (interference relations, transfer traps), recorded separately from mistakes with explanation, source, pattern family; occurrences merge by stable id.
  - `LanguageConceptSignals.afterAnswer` EWMA updates (recall difficulty/speed, usage frequency, transfer errors, native interference) + `LanguageSignalsStore`; persistence seams with in-memory demo implementations.
  - Core engine reused unchanged: `LearnerEngine(graph: languageGraph.toCoreGraph())`, answers exercise full concept lineage.
  - Language Lab UI: `/language` (animated per-skill mastery, misconception Teacher Notes, repair-first daily lesson preview) + `/language/concept/:id` (signals, graph relations, pattern family, live simulate buttons); entry card on the main dashboard; app title now "Adaptive Language Platform".
  - Verified: `flutter analyze` clean; 110 tests green (9 tracking + 2 widget tests new); web app boots and renders (manual screenshot blocked by tooling, screens verified by widget tests).

- Phase 1 — Language domain model (2026-07-16, ADR-0015):
  - `lib/language/` pure-Dart layer: 11-tier language hierarchy with hierarchical concept ids, typed nodes (grammar concepts with transfer traps, vocabulary with lemma/translations/frequency, phrases, examples, exercises, conversations), CEFR levels, 10 skills.
  - `LanguageKnowledgeGraph`: typed relations (requires, buildsOn, interferesWith, culturalContext, falseFriend, relatedTo); `toCoreGraph()` projection — core engine consumes language structure unchanged (zero diffs under `lib/adaptive/`).
  - Language memory signals (`LanguageConceptSignals`) beside the core LearnerModel; per-skill mastery aggregation (`skillMastery`, `weakestSkills`).
  - CEFR curricula as JSON data: schema + loader + `es-for-en` / `en-for-es` seeds (tener-states misconception family, ser/estar, embarazada + actually false friends, pro-drop interference, cultural context).
  - Firestore schema drafts: `docs/database/05-language-schema.md`.
  - Verified: `flutter analyze` clean; 99 tests green (89 inherited unchanged + 10 new in `test/language_domain_test.dart`).

- Phase 0 — Fork foundation (2026-07-12):
  - Repository `adaptive-language-platform` created as history-preserving fork of `adaptive-exam-platform` (ADR-0014). Independent remote; original repo untouched.
  - Product identity: README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG rewritten for the language platform.
  - ADR structure continued: 0001–0013 inherited (binding for the Adaptive Learning Core), 0014 records the fork decision.

## In Progress

- Phase 8 infra (blocked on Firebase keys): Firestore repository swap behind the existing seams, real speech/AI vendor adapters, analytics + crash reporting, iOS/web parity, onboarding, package rename. See `PRODUCTION_CHECKLIST.md`.

## Inherited at Fork Point (commit 3b597b2 lineage)

Working Adaptive Learning Core from the exam platform, reused as-is:

- Flutter app (`app/flutter/`, Flutter 3.44.5, Riverpod 3, go_router 16) in demo mode (ADR-0006).
- Adaptive engine (`lib/adaptive/`, ADR-0008): learner model, knowledge graph, spaced repetition, confidence, selector, study plans, Learning DNA — pure Dart.
- AI orchestration (`lib/ai/`, ADR-0010): AiChatModel vendor seam, AiOrchestrator, FakeChatModel.
- Content intelligence (ADR-0011): chunked imports, quality engine, document ingestion, review queue.
- Content Studio (`/admin`, ADR-0007/0009): CRUD, versioning, bulk ops, import analytics.
- Enterprise platform (ADR-0012/0013): tenant isolation (CI-tested rules), library inheritance, curriculum hierarchy, search/notification seams.
- 89 Flutter tests + 22 Firestore rules tests green at fork point; CI workflow inherited.

Note: inherited domain code still uses exam vocabulary (questions, exams, topics). Remodeling to the language hierarchy is Phase 1 — docs describe the target; code catches up phase by phase.

## Next

- Phase 8 infra: Firebase integration + Firestore repository swap (schema drafted, seams ready), real speech/AI/analytics providers, iOS/web parity, package rename. Also: AI extractor over the review queue, cloud speech models, tutor history persistence. See ROADMAP.md + PRODUCTION_CHECKLIST.md.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- Language Lab starts demo-seeded (deterministic scripted learner per language, reseeds on restart/switch); practice sessions layer real answer events on top. Exam-era screens are unrouted dead code until the package rename deletes them (backlog).
- Exercise pool bounded by curriculum richness (A1 slices) until Phase 7 content ingestion.
- Firebase production integration deferred to Phase 8 (runbooks in `docs/deployment/`).
- `docs/product/`, `docs/architecture/`, `docs/database/` subtrees still describe the exam domain; rewritten incrementally as each phase touches them.
