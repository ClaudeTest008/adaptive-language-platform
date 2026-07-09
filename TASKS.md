# Tasks

## Active

- Epic 14 prerequisite (HUMAN): follow `docs/deployment/01-firebase-setup.md` — firebase login, create projects, deploy rules/indexes/functions, bootstrap admin.
- After Firebase setup: Firestore repository implementations (Auth/Content/Study/Admin/LearnerModel) + `flutterfire configure`; rules deltas from `docs/database/04-adaptive-schema.md`.
- Content Studio spec remainder: Excel/upload/image import, version history + rollback, new-exam wizard, user management, import analytics (`docs/product/07`).

## Backlog

- Firestore repository implementations + firebase packages + `flutterfire configure` (after Epic 4 deploy).
- Localization scaffolding (ARB/intl) — deferred by ADR-0006.
- Widget + integration tests; rules emulator tests (needs Firebase CLI + Java).

## Done

- [x] Epic 0 — Repository foundation (2026-07-07).
- [x] Epic 1 — Product definition docs in `docs/product/`; CONTRIBUTING.md (2026-07-08).
- [x] Epic 2 — Architecture docs, security architecture, ADRs 0001–0004 (2026-07-08).
- [x] Epic 3 — Database design docs, deployable rules/indexes files, ADR-0005 (2026-07-08).
- [x] Epic 4 code — Cloud Functions (4 functions, tsc-verified), firebase.json, set-admin script, setup runbook (2026-07-08).
- [x] Epics 5–9 — full learner app in demo mode, analyze clean, 11 tests, browser-verified; CI workflow (2026-07-09).
- [x] Epic 10 V1 slice — Content Studio: question CRUD, exam settings, CSV/JSON import pipeline, content packs; 21 tests (2026-07-09).
- [x] Epic 13 — Adaptive learning engine (model, graph, scheduler, confidence, selector, readiness, plans, DNA, AI interfaces); 41 tests total; browser-verified (2026-07-09).
- [x] Epic 15 core — Content Studio V2: workflow states, versioning + rollback, bulk ops, import analytics, learner-model codec, swap guide; 52 tests total (2026-07-09).
