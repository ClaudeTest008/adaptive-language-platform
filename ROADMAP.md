# Roadmap

Master plan for the Adaptive Language Platform. Phases are sequential; each ends with working, tested, documented software. Inherited exam-platform epics (0–18) live in the git history and the original repository; this roadmap starts fresh for the language product.

## Phase 0 — Fork Foundation ✅ (2026-07-12)

- Repository `adaptive-language-platform` created as history-preserving fork of `adaptive-exam-platform` (ADR-0014).
- Product identity: README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG rewritten for the language platform.
- ADR structure continued (0001–0013 inherited; 0014 records the fork).

## Phase 1 — Language Domain Model ✅ (2026-07-16)

- ✅ Language knowledge hierarchy (`lib/language/entities.dart`): 11-tier `LanguageNode` discipline, typed grammar/vocabulary/phrase/example/exercise/conversation nodes, CEFR levels, 10 skills. (ADR-0015)
- ✅ Knowledge graph extension (`lib/language/relationships.dart`): typed relations (requires, buildsOn, interferesWith, culturalContext, falseFriend, relatedTo) projected onto the unchanged core graph.
- ✅ Language signals + per-skill mastery (`lib/language/signals.dart`): recall difficulty/speed, pronunciation confidence, listening recognition, grammar-transfer errors, usage frequency, native interference; `skillMastery`/`weakestSkills`.
- ✅ CEFR curriculum as data: JSON schema + loader + Spanish-for-English and English-for-Spanish seeds (`assets/curriculum/`).
- ✅ Firestore schema drafts: `docs/database/05-language-schema.md`.
- ✅ Tests: hierarchy ids/lineage, tier validation, relation queries, core projection, skill aggregation, seed parsing (10 new; 99 total green).

## Phase 2 — Vocabulary & Grammar Adaptive Tracking ✅ (2026-07-16)

- ✅ Language signals from answer events (ADR-0016): EWMA recall difficulty/speed, usage frequency, grammar-transfer errors, native interference — beside the unchanged core model (`signals.dart`, `LanguageSignalsStore` + repository seam).
- ✅ Per-skill mastery aggregation surfaced in UI (Language Lab dashboard: per-skill animated bars).
- ✅ Misconception engine (`misconceptions.dart`): graph-authorized detection (interference relations + transfer traps), log separate from mistakes, occurrences merge, related-concept pattern families; Teacher Notes UI.
- ✅ Core engine reused unchanged for language mastery: `LearnerEngine(graph: toCoreGraph())`, lineage concept ids.
- ✅ Showcase UI: `/language` dashboard + `/language/concept/:id` detail with live simulate (ADR-0016).
- ✅ Daily lesson preview (repair-first stopgap; full engine in Phase 4).
- ✅ Tests: detection, log merge, signal updates, end-to-end through core engine, widget tests for both screens (110 total green).
- ✅ Text-first exercise flows (ADR-0017): five types derived from curriculum data, deterministic generation, `/language/practice` session with inline teacher notes; lineage-walking misconception detection; dashboard "Practice your weak spots" CTA.
- Deferred to Phase 4: learning-goals schema usage (first consumer is the lesson engine).

## Phase 3 — AI Tutor Foundation (foundation complete 2026-07-16)

- ✅ Tutor foundation (ADR-0018, `lib/language/tutor.dart`): provider-blind over the `AiChatModel` seam (ADR-0010, `lib/ai/` untouched); every output validated (structure + focus-concept grounding), rejected output never reaches the learner.
- ✅ Context assembly: `TutorContext` snapshot — skill mastery, weakest concepts, misconceptions, signals, goals, Learning DNA traits, knowledge-graph slice (focus relations + pattern family). Default focus = top misconception (repair first).
- ✅ Six mode contracts (Teacher, Conversation, Coach, Socratic, Grammar, Immersion): distinct personas + serialized learner context; `/language/tutor` mode selector + chat session UI; dashboard tutor CTA; DemoTutorModel live Teacher-mode flow from real graph data.
- ✅ Tests: context assembly, mode prompts, validation gate, tutor service (valid/invalid/history), demo teacher flow, widget test (131 total green).
- ✅ Dialogue depth (ADR-0018 addendum): per-mode `Session flow` dialogue plans in prompts, mode-true DemoTutorModel strategies (multi-turn aware), immersion language-purity validation (native-stopword gate), live Learning DNA in every TutorContext; typing indicator + avatar chat bubbles; interactive Today's Plan (blocks launch focused practice); exercise-type interleaving.
- ⏳ Remaining (deeper Phase 3): tutor history persistence (schema drafted), session summaries feeding Learning DNA, real vendor adapters (API keys).

## Phase 4 — Daily Personalized Lesson Engine ✅ (2026-07-17, ADR-0022)

- ✅ `buildDailyLesson` generates the plan from mastery, weak areas, spaced-repetition due concepts, pronunciation confidence, Learning DNA traits, available time and recent accuracy.
- ✅ Weighted, time-budgeted blocks across activities (repair, review, grammar/vocab, pronunciation, story, conversation); repair first; each block carries a reason + a launchable activity (practice/speaking/story/tutor).
- ✅ Tappable plan blocks launch the right activity; enriched narrative stories; warmer TTS (rate/pitch/voice selection).
- ✅ Tests: determinism, budget, repair-first, spaced-repetition, pronunciation, DNA shaping, story overlap (8 new; 155 total).
- ⏳ Remaining: real `nextReviewAt` scheduling once sessions carry timestamps (Phase 8); minutes selector from learner goals.

## Phase 5 — Conversation Engine ✅ (2026-07-17, ADR-0023)

- ✅ Scenario-driven multi-turn dialogue for Conversation + Immersion modes; vocabulary steered to weak concepts; tutor reacts to the learner, recasts errors, progresses the scene, ends with a follow-up.
- ✅ `conversationAbility` signal via `afterConversationTurn` + `conversationTurnQuality`; recorded per learner turn on the scenario concept.
- ✅ Wired: Conversation plan block launches a Conversation session; enriched scenario data.
- ✅ Voice naturalness: sentence-chunked speech with breaths, question-pitch lift, full volume, warmer defaults + enhanced-voice selection.
- ✅ Tests: scenario selection, context/vocab assembly, turn quality, signal, contextual demo dialogue (11 new; 165 total).
- ⏳ Remaining: feed `conversationAbility` into the lesson engine; A2+ scenarios; real neural prosody (cloud speech, Phase 6).

## Phase 6 — Speech & Pronunciation ✅ (2026-07-17, ADR-0020/0024)

- ✅ Speaking practice + pronunciation scoring (Phase-2 foundation), now **phoneme-aware edit-distance scoring with per-word ✓/✗ feedback** (ADR-0024).
- ✅ Speech provider seam (`SpeechService`, flutter_tts + speech_to_text adapter); prosodic clause-chunked TTS with per-language tuning.
- ✅ **Listening recognition** exercise + `listeningRecognition` signal (hear a word, pick it).
- ✅ `pronunciationConfidence` + `conversationAbility` signals now **weight the daily lesson** (speaking/conversation blocks grow when weak).
- ⏳ Remaining: real cloud phoneme/prosody models; pronunciation-attempt persistence (schema drafted, Phase 8).

## Phase 7 — Content Ingestion for Language Resources ✅ (2026-07-17, ADR-0025)

- ✅ Language content extractor (`ingestLanguageText`): pasted text → review candidates across vocabulary, phrases, example sentences, idioms, cultural notes; difficulty + topics; mapped to curriculum concept ids where recognized.
- ✅ Human review queue (`ContentReviewLog`/repository seam) — nothing enters the curriculum without approval.
- ✅ Admin Content Studio (`/content`, admin-gated): paste/sample → extract → preview + approve/reject.
- ✅ Keyboard cleanup (unfocus on submit/advance); four new narrative stories (A1/A2).
- ⏳ Remaining: merge approved candidates into live curriculum/stories (Phase 8 persistence); AI extractor over the same queue; binary-format (PDF/DOCX/audio) ingestion; content-source schema.

## Phase 8 — Production Deployment (demo-mode slice complete 2026-07-17, ADR-0026)

- ✅ Ingestion loop closed: approved Content-Studio candidates merge into the live curriculum (new concepts + exercises) and stories, behind the existing seams (`mergeApprovedContent`/`storyFromApproved`).
- ✅ Learner goals (minutes/day + target CEFR level) drive `availableMinutesProvider` (plan time budget) and the story queue; `/goals` surface.
- ✅ `PRODUCTION_CHECKLIST.md` — pre-launch tracker (persistence swap, real speech/AI providers, iOS parity, analytics).
- ⏳ Remaining (needs infra/keys): Firebase project + Firestore repository swap (schema drafted, seams ready), real speech/AI providers, analytics + crash reporting, iOS/web parity, onboarding, package rename.

## Principles

- The Adaptive Learning Core is extended, never rewritten.
- Language features stay separated from the core.
- No vendor lock-in; AI output always validated.
- Repository is the single source of truth; every session updates status docs and commits.
