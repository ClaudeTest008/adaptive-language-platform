# Project Status

**Phase:** Epic 4 — Backend Foundation (next)
**Last updated:** 2026-07-08

## Completed

- Epic 0 — Repository foundation: structure, docs, GitHub repo, CI directories.
- Epic 1 — Product definition: `docs/product/` (requirements, personas, learning philosophy, metrics, risks); CONTRIBUTING.md.
- Epic 2 — System architecture: `ARCHITECTURE.md`; `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging); `docs/security/`; ADRs 0001–0004 (stack, Riverpod+go_router, admin panel same codebase, offline strategy).
- Epic 3 — Database design: `docs/database/` (schema, rules/validation strategy, indexes/migration); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005.

## In Progress

- Nothing.

## Next

- Epic 4 — Backend foundation: create Firebase projects (dev/prod), deploy rules/indexes, Cloud Functions scaffold (`setUserRole`, `onUserCreate`, `deleteUserData`, `aggregateQuestionStats`), rules emulator tests. Requires Firebase CLI login (interactive — human step).

## Known Limitations

- No application code yet (starts Epic 4/5).
- `app/`, `backend/`, `cloud_functions/`, `tests/` are placeholders.
