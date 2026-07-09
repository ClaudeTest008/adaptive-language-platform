# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- 2026-07-08: Epic 4 (code) — Cloud Functions TypeScript project: `onUserCreate`, `setUserRole`, `deleteUserData`, `aggregateQuestionStats`; `firebase.json`; collection-group index override for attempts; `scripts/set-admin.js`; Firebase setup runbook in `docs/deployment/`.
- 2026-07-08: Epic 3 — database design: `docs/database/` (Firestore schema and access patterns, security rules and validation strategy, indexes and migration strategy); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005.
- 2026-07-08: Epic 2 — system architecture: full `ARCHITECTURE.md`, `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging), `docs/security/01-security-architecture.md`, ADRs 0001–0004.
- 2026-07-08: Epic 1 — product definition: business requirements, product requirements (FR/NFR), personas and user journeys, learning philosophy, success metrics, risk assessment (`docs/product/`); `CONTRIBUTING.md`; roadmap expanded to Epics 0–12.
- 2026-07-07: Phase 0, Milestone 0.1 — repository created with full directory structure and foundation documents.
