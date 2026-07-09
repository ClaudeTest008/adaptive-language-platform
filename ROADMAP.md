# Master Roadmap v2.0

Work executes in this exact order. One epic at a time. Do not repeat completed epics.

| Epic | Title | Status |
|------|-------|--------|
| 0 | Repository Foundation | ✅ Complete |
| 1 | Product Definition | ✅ Complete |
| 2 | System Architecture | ✅ Complete |
| 3 | Database Design | ✅ Complete |
| 4 | Backend Foundation | 🟡 Code complete; deploy blocked on human Firebase login |
| 5 | Flutter Foundation | ✅ Complete (demo mode, ADR-0006) |
| 6 | Question Engine | ✅ Complete (demo mode) |
| 7 | Practice Mode | ✅ Complete |
| 8 | Mock Exams | ✅ Complete |
| 9 | Progress Dashboard | ✅ Complete |
| 10 | Admin Panel / Content Studio | 🟡 V1 slice complete (ADR-0007); full spec in docs/product/07 |
| 11 | Testing | 🟡 Partial (41 tests incl. adaptive engine; widget/integration pending) |
| 12 | Deployment | 🟡 Partial (CI workflow added; builds/deploy pending Firebase) |
| 13 | Adaptive Learning Engine | ✅ V1 complete (ADR-0008) |
| 14 | Firebase Production Integration | ⏳ Blocked on human setup; all contracts + swap guide ready (docs/deployment/01+02) |
| 15 | Content Studio V2 | 🟡 Core complete (ADR-0009); Excel/images/scheduling with Epic 14 |

## Epic 0 — Repository Foundation ✅

Repository created with full directory structure and foundation documents. See `README.md` for layout.

## Epic 1 — Product Definition ✅

Delivered in `docs/product/`:
- Business requirements (`01-business-requirements.md`)
- Product requirements: functional + non-functional (`02-product-requirements.md`)
- Personas and user journeys (`03-personas-and-user-journeys.md`)
- Learning philosophy (`04-learning-philosophy.md`)
- Success metrics (`05-success-metrics.md`)
- Risk assessment (`06-risk-assessment.md`)

## Epic 2 — System Architecture ✅

Delivered: full `ARCHITECTURE.md`; `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging); `docs/security/01-security-architecture.md`; ADRs 0001–0004 in `docs/decisions/`.

## Epic 3 — Database Design ✅

Delivered: `docs/database/` (schema + access patterns, security rules and validation strategy, indexes and migration strategy); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005 (denormalized questions, client-side scoring).

## Epic 4 — Backend Foundation 🟡

Code complete: `cloud_functions/` TypeScript project (`onUserCreate`, `setUserRole`, `deleteUserData`, `aggregateQuestionStats`), compiles clean; `firebase.json` deploy config; `scripts/set-admin.js` admin bootstrap; `docs/deployment/01-firebase-setup.md`.

Remaining (human, interactive): `firebase login`, create dev/prod projects, enable services, deploy rules/indexes/functions, bootstrap first admin — exact steps in `docs/deployment/01-firebase-setup.md`.

## Epic 5 — Flutter Foundation

App scaffold, navigation/routing, dependency injection, theme (Material 3, light/dark), localization scaffolding, shared components.

## Epic 6 — Question Engine

Question repository, answer validation, bookmarks, review-incorrect, search.

## Epic 7 — Practice Mode

Question flow, immediate feedback, explanations, statistics recording.

## Epic 8 — Mock Exams

Randomization, timer, scoring, pass/fail, results storage.

## Epic 9 — Progress Dashboard

Statistics, weak topics, study history, achievements (basic).

## Epic 10 — Admin Panel / Content Studio 🟡

Full requirements: `docs/product/07-content-studio-requirements.md`. V1 slice delivered (ADR-0007): Content Studio at `/admin` — overview with content stats, exam settings editor, question management (search, status filter, visual editor, archive-not-delete, version bump on edit), bulk import pipeline (CSV/JSON: parse → schema → validation → duplicate detection → topic mapping → report → approval → import as drafts or published), content-pack JSON export/import.

Remaining for full spec: Excel/upload/image import, full version history + rollback + scheduled publishing, new-exam wizard, regions/subtopics/objectives UI, user management, import analytics, search index, marketplace packs, AI assists.

## Epic 11 — Testing

Unit tests, widget tests, integration tests, performance checks, testing documentation.

## Epic 12 — Deployment

CI/CD (GitHub Actions: format, analyze, test, build), production builds, Firebase deployment, documentation, release candidate.

## Epic 13 — Adaptive Learning Engine ✅ (V1)

Delivered (ADR-0008): pure-Dart engine in `app/flutter/lib/adaptive/` — learner model (per-concept mastery, streaks, lapses, response times), knowledge graph derived from content with lapse propagation, spaced repetition behind a replaceable `ReviewScheduler` (SM-2/FSRS-ready), confidence model, adaptive question selector (due > weak > unseen > consolidation), exam readiness + pass probability, personalized study plan, learning DNA traits. AI platform foundations as provider-independent interfaces (`lib/domain/ai_services.dart`). Wired into practice + mock exams; dashboard readiness card; "Adaptive session" practice entry. Schema extension documented in `docs/database/04-adaptive-schema.md`.

Deferred: learner model Firestore persistence (with Epic 14), per-question exam timing, SM-2/FSRS scheduler, admin analytics dashboards, AI implementations.

## Epic 14 — Firebase Production Integration ⏳

Blocked on human steps (`docs/deployment/01-firebase-setup.md`): create projects, deploy rules/indexes/functions. Then: firebase packages + `flutterfire configure`, Firestore implementations of `AuthRepository`/`ContentRepository`/`StudyRepository`/`AdminRepository`/`LearnerModelRepository` behind unchanged interfaces (swap = provider bindings in `lib/presentation/providers.dart`), Analytics/Crashlytics wiring, App Check, Remote Config, rules emulator tests.

## Epic 15 — Content Studio V2 🟡 (core delivered)

Delivered (ADR-0009): 5-state workflow (draft/review/approved/published/archived, learners see published only), append-only question version history with rollback-as-new-version, bulk operations (publish/archive/tag) through the versioned path, import job history + duplicate analytics, topic-coverage and author analytics, expanded AI interfaces (OCR, content review, metadata generation), LearnerModel JSON codec (Firestore contract, round-trip tested), Firestore swap guide (`docs/deployment/02-firestore-swap-guide.md`).

Deferred to Epic 14 implementation or later (reasons in ADR-0009): Excel import, file upload, image pipeline, scheduled publishing, role-separated review workflow, question usage/accuracy analytics, marketplace/white-label packs.

## Version 2+ (not V1 — architecture-ready only)

Additional exam categories, adaptive learning, AI tutor/explanations/study plans, knowledge graph, spaced repetition, institutional/corporate features, white-label deployments, monetization.
