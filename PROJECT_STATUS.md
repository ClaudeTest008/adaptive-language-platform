# Project Status

**Phase:** Epic 4 code complete (deploy = human step); Epic 5 next (needs Flutter SDK)
**Last updated:** 2026-07-08

## Completed

- Epic 0 — Repository foundation: structure, docs, GitHub repo, CI directories.
- Epic 1 — Product definition: `docs/product/` (requirements, personas, learning philosophy, metrics, risks); CONTRIBUTING.md.
- Epic 2 — System architecture: `ARCHITECTURE.md`; `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging); `docs/security/`; ADRs 0001–0004 (stack, Riverpod+go_router, admin panel same codebase, offline strategy).
- Epic 3 — Database design: `docs/database/` (schema, rules/validation strategy, indexes/migration); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005.
- Epic 4 (code) — Cloud Functions in TypeScript (compile-verified), `firebase.json`, admin bootstrap script, Firebase setup runbook (`docs/deployment/01-firebase-setup.md`).

## In Progress

- Epic 4 (deploy) — BLOCKED on human: `firebase login`, project creation, service enablement, deploy. Runbook: `docs/deployment/01-firebase-setup.md`.

## Next

- Epic 5 — Flutter foundation. BLOCKED on: Flutter SDK not installed on this machine (`flutter` not on PATH). Install Flutter, then scaffold app per `docs/architecture/02-flutter-architecture.md`.

## Known Limitations

- No application code yet (starts Epic 4/5).
- `app/`, `backend/`, `cloud_functions/`, `tests/` are placeholders.
