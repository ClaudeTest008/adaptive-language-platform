# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- 2026-07-09: Epic 13 — adaptive learning engine (`lib/adaptive/`): learner model with per-concept mastery/streaks/lapses/response times, knowledge graph with lapse propagation, spaced repetition behind replaceable `ReviewScheduler`, confidence model, adaptive question selector, exam readiness + pass probability, personalized study plans, learning DNA; provider-independent AI service interfaces; dashboard readiness card; adaptive practice sessions; Firestore schema extension doc; ADR-0008.
- 2026-07-09: Epic 10 V1 slice — Content Studio (`/admin`): overview, exam settings editor, question management with visual editor and archive/versioning, CSV/JSON bulk import pipeline with validation report and approval, content-pack export/import; question metadata (difficulty, tags, status, version, author); Content Studio requirements doc; ADR-0007.
- 2026-07-09: Epics 5–9 — Flutter learner app (`app/flutter/`): auth, dashboard (stats, weak topics, history), practice mode (feedback, explanations, bookmarks, review-incorrect), timed mock exams with per-question review, search, settings; in-memory demo repositories (ADR-0006); 11 tests; CI workflow.
- 2026-07-08: Epic 4 (code) — Cloud Functions TypeScript project: `onUserCreate`, `setUserRole`, `deleteUserData`, `aggregateQuestionStats`; `firebase.json`; collection-group index override for attempts; `scripts/set-admin.js`; Firebase setup runbook in `docs/deployment/`.
- 2026-07-08: Epic 3 — database design: `docs/database/` (Firestore schema and access patterns, security rules and validation strategy, indexes and migration strategy); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005.
- 2026-07-08: Epic 2 — system architecture: full `ARCHITECTURE.md`, `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging), `docs/security/01-security-architecture.md`, ADRs 0001–0004.
- 2026-07-08: Epic 1 — product definition: business requirements, product requirements (FR/NFR), personas and user journeys, learning philosophy, success metrics, risk assessment (`docs/product/`); `CONTRIBUTING.md`; roadmap expanded to Epics 0–12.
- 2026-07-07: Phase 0, Milestone 0.1 — repository created with full directory structure and foundation documents.
