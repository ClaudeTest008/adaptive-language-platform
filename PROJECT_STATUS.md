# Project Status

**Phase:** Phase 1 — Language Domain Model (complete)
**Last updated:** 2026-07-16

## Completed

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

## In Progress

- Nothing. Phase 1 closed.

## Next

- Phase 2 — Vocabulary & grammar adaptive tracking: wire language signals into answer-event flows, misconception engine (interference detection on errors), text-first exercise types, per-skill mastery surfaced in app. See ROADMAP.md.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- Language domain model exists (`lib/language/`) but nothing consumes it at runtime yet; app still behaves as the exam product until Phase 2 lands.
- Firebase production integration deferred to Phase 8 (runbooks in `docs/deployment/`).
- `docs/product/`, `docs/architecture/`, `docs/database/` subtrees still describe the exam domain; rewritten incrementally as each phase touches them.
