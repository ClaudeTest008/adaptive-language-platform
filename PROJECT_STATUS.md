# Project Status

**Phase:** Phase 2 — Vocabulary & Grammar Adaptive Tracking (core complete; exercise flows remaining)
**Last updated:** 2026-07-16

## Completed

- Phase 2 core — misconception engine + signal tracking + Language Lab UI (2026-07-16, ADR-0016):
  - Misconception engine: graph-authorized detection (interference relations, transfer traps), recorded separately from mistakes with explanation, source, pattern family; occurrences merge by stable id.
  - `LanguageConceptSignals.afterAnswer` EWMA updates (recall difficulty/speed, usage frequency, transfer errors, native interference) + `LanguageSignalsStore`; persistence seams with in-memory demo implementations.
  - Core engine reused unchanged: `LearnerEngine(graph: languageGraph.toCoreGraph())`, answers exercise full concept lineage.
  - Language Lab UI: `/language` (animated per-skill mastery, misconception Teacher Notes, repair-first daily lesson preview) + `/language/concept/:id` (signals, graph relations, pattern family, live simulate buttons); entry card on the main dashboard; app title now "Adaptive Language Platform".
  - Verified: `flutter analyze` clean; 110 tests green (9 tracking + 2 widget tests new); web app boots and renders (manual screenshot blocked by tooling, screens verified by widget tests).

## In Progress

- Phase 2 remainder: text-first exercise flows (multiple choice, fill-in-blanks, translation, sentence building, reading comprehension) calling `LanguageLearnerController.recordAnswer`.

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

- Finish Phase 2: exercise flows (see In Progress), then Phase 3 — AI tutor foundation over `lib/ai/` orchestrator consuming MisconceptionLog + signals. See ROADMAP.md.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- Language Lab is a demo-seeded showcase (deterministic scripted learner, reseeds on restart); real exercise flows are the Phase 2 remainder. Exam-era practice/mock screens still present alongside.
- Firebase production integration deferred to Phase 8 (runbooks in `docs/deployment/`).
- `docs/product/`, `docs/architecture/`, `docs/database/` subtrees still describe the exam domain; rewritten incrementally as each phase touches them.
