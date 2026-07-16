# Tasks

## Active

- Phase 2 remainder: text-first exercise flows (multiple choice, fill-in-blank, translation, sentence building, reading comprehension) rendering `ExerciseNode`s and calling `LanguageLearnerController.recordAnswer` — replaces demo seeding as the source of real answer events.

## Backlog

- Phase 3: AI tutor foundation — context assembly (MisconceptionLog + signals + skill mastery + Learning DNA) + six modes over `lib/ai/` orchestrator.
- Phase 4: daily lesson engine (replaces `lesson.dart` preview heuristics; review schedule, goals, past performance).
- Phases 5–8: conversation engine, speech/pronunciation, language content ingestion, production deployment. See ROADMAP.md.
- Learning-goals schema (docs/database/05) — first consumer is the Phase 4 lesson engine.
- Grow curriculum seeds beyond A1 slices (A2+, more domains) — data-only work.
- Rewrite `docs/product/` for the language product — incremental, as phases touch them.
- Rename `adaptive_exam_platform` package + retire exam-era screens once exercise flows replace practice/mock (no premature renames).

## Done

- [x] Phase 2 core — misconception engine (graph-authorized, separate from mistakes), EWMA signal tracking + store + repository seams, core engine reused via `toCoreGraph()`, Language Lab UI (`/language`, `/language/concept/:id`) with live simulate, lesson preview stopgap, ADR-0016; 11 new tests, 110 total green (2026-07-16).
- [x] Phase 1 — Language domain model: `lib/language/` (entities, relationships, signals, curriculum loader), curriculum JSON schema + es/en seeds, Firestore schema drafts, ADR-0015, 10 new tests (99 total green) (2026-07-16).
- [x] Phase 0 — Fork foundation: repo created from adaptive-exam-platform with full history, docs rebranded, ADR-0014, pushed to GitHub (2026-07-12).
