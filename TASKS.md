# Tasks

## Active

- Epic 10: admin panel (`/admin/*` routes, exam/question CRUD against repository interfaces).
- Epic 4 deploy (HUMAN): follow `docs/deployment/01-firebase-setup.md` — firebase login, create projects, deploy rules/indexes/functions, bootstrap admin.

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
