# Tasks

## Active

- Delete unrouted exam-era screens (dashboard/practice/mock/bookmarks/search/admin studio) together with the `adaptive_exam_platform` → `adaptive_language_platform` package rename (single sweep; ADR-0019 retired them from navigation).

- Phase 3: tutor history persistence seam (`tutorHistory` shape in docs/database/05) + session summaries feeding Learning DNA.

## Backlog

- Real vendor adapters (AnthropicChatModel/OpenAiChatModel/...) behind `tutorModelProvider` — blocked on API keys.
- Phase 6: real phoneme scoring; Phases 7–8: content ingestion, production. See ROADMAP.md.
- Feed `conversationAbility` into the daily lesson engine (weight a conversation block when it's low); A2+ conversation scenarios.
- Grow curriculum seeds beyond A1 slices (A2+, more domains) — data-only; enlarges exercise pool + tutor material + story queue.
- Real phoneme-level pronunciation scoring (speech models) replacing token-overlap proxy; listening-recognition signal (ADR-0020 remainder); real neural prosody via cloud speech.
- Lesson engine follow-ups: minutes selector from learner goals (drive `availableMinutesProvider`); real `nextReviewAt` scheduling once sessions carry timestamps (Phase 8).
- Grow story seeds (more stories per language/level, A2+ mini-adventures).
- Rewrite `docs/product/` for the language product — incremental, as phases touch them.
- Remove demo seed once real learner accounts persist language state (Firestore swap, Phase 8).

## Done

- [x] Phase 5 — Conversation Engine (scenario-driven multi-turn dialogue for Conversation/Immersion, weak-weighted scenario + target-vocab steering, reacts/recasts/progresses/follows-up, `conversationAbility` signal per turn), enriched scenarios, sentence-chunked prosodic TTS, ADR-0023; 165 tests green; emulator-verified (recast of a live "soy cansado" turn) (2026-07-17).

- [x] Phase 4 — Daily Lesson Engine (`buildDailyLesson`: weighted time-budgeted blocks from DNA + spaced repetition + weak areas + pronunciation + stories; per-block reason + launchable activity; tappable plan blocks), enriched narrative stories, warmer TTS (rate/pitch/voice), ADR-0022; 155 tests green; emulator verified (2026-07-17).
- [x] Content & Voice — short stories (data + level-matched reader with TTS), speaking practice (graph drills + pronunciation scoring → signals + core AnswerEvent), tutor voice (speak bubbles, auto-speak toggle, mic dictation), provider-blind speech seam, bottom-nav shell replacing the FAB, ADR-0020/0021; 147 tests green; Android emulator verified (2026-07-16).

- [x] Phase 3 dialogue depth — per-mode Session-flow plans + MODE tag in prompts, six mode-true DemoTutorModel strategies (multi-turn aware), immersion purity gate (native stopwords), live Learning DNA in TutorContext, typing indicator + avatar bubbles, tappable Today's Plan blocks, exercise-type interleaving; Android emulator run verified with screenshots; 137 tests green (2026-07-16).

- [x] Product rebrand — language-first navigation (Language Lab at `/`, exam routes retired), multi-language selector with per-language seeds + contamination fix, teal immersion theme, tutor hero + FAB, rebranded copy/manifest, ADR-0019; 132 tests green (2026-07-16).
- [x] Phase 3 foundation — AI tutor: TutorContext assembly, six mode contracts, output validation with grounding, provider-blind LanguageTutor + DemoTutorModel, `/language/tutor` UI + dashboard CTA, ADR-0018; 131 tests green (2026-07-16).
- [x] Phase 2 finish — text-first exercise flows derived from curriculum data (5 types, deterministic, repair-focused), `/language/practice` session with inline teacher notes, lineage-walking detection, dashboard CTA, seed enrichment, ADR-0017; 120 tests green; web boot verified (2026-07-16).
- [x] Phase 2 core — misconception engine (graph-authorized, separate from mistakes), EWMA signal tracking + store + repository seams, core engine reused via `toCoreGraph()`, Language Lab UI with live simulate, lesson preview stopgap, ADR-0016; 110 tests green (2026-07-16).
- [x] Phase 1 — Language domain model: `lib/language/` (entities, relationships, signals, curriculum loader), curriculum JSON schema + es/en seeds, Firestore schema drafts, ADR-0015; 99 tests green (2026-07-16).
- [x] Phase 0 — Fork foundation: repo created from adaptive-exam-platform with full history, docs rebranded, ADR-0014, pushed to GitHub (2026-07-12).
