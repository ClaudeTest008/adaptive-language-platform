# Tasks

## Active

- Phase 1 kickoff: design language domain entities (Language, Level, Skill, Domain, Topic, GrammarConcept, VocabularyConcept, Phrase, ExampleSentence, Exercise, Conversation) as pure-Dart domain model; write ADR for the language domain model.
- Phase 1: map language hierarchy onto curriculum-hierarchy concept ids (ADR-0012) so the adaptive engine consumes language concepts unchanged.
- Phase 1: Firestore schema drafts — languages, learners, skills, vocabulary, grammar concepts (`docs/database/`).

## Backlog

- Phase 2: language memory signals in adaptive engine (additive), per-skill mastery aggregation, misconception engine, text-first exercise types.
- Phase 3: AI tutor foundation — context assembly + six modes over `lib/ai/` orchestrator.
- Phase 4: daily lesson engine (time-budgeted plans).
- Phases 5–8: conversation engine, speech/pronunciation, language content ingestion, production deployment. See ROADMAP.md.
- Rewrite `docs/product/` for the language product (business requirements, personas, learning philosophy) — incremental, as phases touch them.
- Rename exam-flavored UI copy and routes when Phase 1–2 domain remodel lands (no premature renames).

## Done

- [x] Phase 0 — Fork foundation: repo created from adaptive-exam-platform with full history, docs rebranded, ADR-0014, pushed to GitHub (2026-07-12).
