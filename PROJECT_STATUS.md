# Project Status

**Phase:** Phase 3 — AI Tutor Foundation (foundation complete; dialogue depth remaining)
**Last updated:** 2026-07-16

## Completed

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

- Phase 3 remainder: tutor history persistence + session summaries feeding Learning DNA; real vendor adapters (blocked on API keys).

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

- Phase 5 — Conversation engine (real dialogue state + vocabulary adaptation), then Phase 6 speech (real phoneme scoring). Also: tutor history persistence, minutes selector from goals, `nextReviewAt` scheduling once sessions carry timestamps. See ROADMAP.md.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- Language Lab starts demo-seeded (deterministic scripted learner per language, reseeds on restart/switch); practice sessions layer real answer events on top. Exam-era screens are unrouted dead code until the package rename deletes them (backlog).
- Exercise pool bounded by curriculum richness (A1 slices) until Phase 7 content ingestion.
- Firebase production integration deferred to Phase 8 (runbooks in `docs/deployment/`).
- `docs/product/`, `docs/architecture/`, `docs/database/` subtrees still describe the exam domain; rewritten incrementally as each phase touches them.
