# Tasks

## Active

- Phase 2 kickoff: misconception engine — on wrong answer, check `LanguageKnowledgeGraph.interference()` + `GrammarConceptNode.transferTraps`, record misconception (separate from mistake) with explanation + related concept ids.
- Phase 2: update `LanguageConceptSignals` from answer events (recall difficulty/speed, usage frequency, native interference); persist beside learner model per `docs/database/05-language-schema.md`.
- Phase 2: text-first exercise types (multiple choice, fill-in-blank, translation, sentence building, reading comprehension) flowing answer events into the adaptive engine via language concept ids.

## Backlog

- Phase 2: surface per-skill mastery (`skillMastery`) in dashboard UI.
- Phase 3: AI tutor foundation — context assembly + six modes over `lib/ai/` orchestrator.
- Phase 4: daily lesson engine (time-budgeted plans; `weakestSkills` input).
- Phases 5–8: conversation engine, speech/pronunciation, language content ingestion, production deployment. See ROADMAP.md.
- Grow curriculum seeds beyond A1 slices (A2+, more domains) — data-only work.
- Rewrite `docs/product/` for the language product — incremental, as phases touch them.
- Rename exam-flavored UI copy, routes, and the `adaptive_exam_platform` package name when Phase 2 domain remodel lands (no premature renames).

## Done

- [x] Phase 1 — Language domain model: `lib/language/` (entities, relationships, signals, curriculum loader), curriculum JSON schema + es/en seeds, Firestore schema drafts, ADR-0015, 10 new tests (99 total green) (2026-07-16).
- [x] Phase 0 — Fork foundation: repo created from adaptive-exam-platform with full history, docs rebranded, ADR-0014, pushed to GitHub (2026-07-12).
