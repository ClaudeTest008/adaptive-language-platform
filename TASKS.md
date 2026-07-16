# Tasks

## Active

- Phase 3 kickoff: AI tutor context assembly — pure builder that packages learner history, skill mastery, MisconceptionLog, LanguageConceptSignals, Learning DNA, goals and weak concepts into a vendor-blind prompt context for the `lib/ai/` orchestrator.
- Phase 3: six tutor modes (Teacher, Conversation, Coach, Socratic, Grammar, Immersion) as orchestrator capabilities with output validation; FakeChatModel-driven tests.

## Backlog

- Phase 4: daily lesson engine (replaces `lesson.dart` preview heuristics; review schedule, goals, past performance); learning-goals schema (docs/database/05) lands with it.
- Phases 5–8: conversation engine, speech/pronunciation, language content ingestion, production deployment. See ROADMAP.md.
- Grow curriculum seeds beyond A1 slices (A2+, more domains) — data-only; directly enlarges the exercise pool (ADR-0017).
- Rewrite `docs/product/` for the language product — incremental, as phases touch them.
- Rename `adaptive_exam_platform` package + retire exam-era practice/mock screens (Language Lab now covers practice).
- Remove demo seed once real learner accounts persist language state (Firestore swap, Phase 8).

## Done

- [x] Phase 2 finish — text-first exercise flows derived from curriculum data (5 types, deterministic, repair-focused), `/language/practice` session with inline teacher notes, lineage-walking detection, dashboard CTA, seed enrichment, ADR-0017; 120 tests green; web boot verified (2026-07-16).
- [x] Phase 2 core — misconception engine (graph-authorized, separate from mistakes), EWMA signal tracking + store + repository seams, core engine reused via `toCoreGraph()`, Language Lab UI (`/language`, `/language/concept/:id`) with live simulate, lesson preview stopgap, ADR-0016; 110 tests green (2026-07-16).
- [x] Phase 1 — Language domain model: `lib/language/` (entities, relationships, signals, curriculum loader), curriculum JSON schema + es/en seeds, Firestore schema drafts, ADR-0015; 99 tests green (2026-07-16).
- [x] Phase 0 — Fork foundation: repo created from adaptive-exam-platform with full history, docs rebranded, ADR-0014, pushed to GitHub (2026-07-12).
