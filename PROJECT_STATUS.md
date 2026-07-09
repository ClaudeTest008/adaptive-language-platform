# Project Status

**Phase:** Epics 5–9 complete in demo mode; Epic 10 (admin panel) next
**Last updated:** 2026-07-09

## Completed

- Epic 0 — Repository foundation: structure, docs, GitHub repo, CI directories.
- Epic 1 — Product definition: `docs/product/` (requirements, personas, learning philosophy, metrics, risks); CONTRIBUTING.md.
- Epic 2 — System architecture: `ARCHITECTURE.md`; `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging); `docs/security/`; ADRs 0001–0004 (stack, Riverpod+go_router, admin panel same codebase, offline strategy).
- Epic 3 — Database design: `docs/database/` (schema, rules/validation strategy, indexes/migration); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005.
- Epic 4 (code) — Cloud Functions in TypeScript (compile-verified), `firebase.json`, admin bootstrap script, Firebase setup runbook (`docs/deployment/01-firebase-setup.md`).
- Epics 5–9 — Flutter app in `app/flutter/` (Flutter 3.44.5, Riverpod 3, go_router 16): auth (demo), dashboard with stats/weak topics/history, practice with immediate feedback/explanations/bookmarks/review-incorrect, timed mock exams with scoring and per-question review, search, settings (theme, sign-out, delete account). Runs against in-memory demo repositories (ADR-0006). Verified: `flutter analyze` clean, 11 tests green, all flows driven in browser (light + dark).
- CI workflow `.github/workflows/ci.yml` (format, analyze, test, web build + functions build).

## In Progress

- Epic 4 (deploy) — BLOCKED on human: `firebase login`, project creation, deploy. Runbook: `docs/deployment/01-firebase-setup.md`.

## Next

- Epic 10 — Admin panel (`/admin/*` routes per ADR-0003).
- Firestore repository implementations replacing demo ones (after Epic 4 deploy); add firebase packages + `flutterfire configure`.
- Deferred debt (ADR-0006): localization scaffolding, widget/integration tests.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- No application code yet (starts Epic 4/5).
- `app/`, `backend/`, `cloud_functions/`, `tests/` are placeholders.
