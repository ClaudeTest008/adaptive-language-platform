# Project Status

**Phase:** Epic 13 (Adaptive Learning Engine) complete; Epic 14 (Firebase) blocked on human setup
**Last updated:** 2026-07-09

## Completed

- Epic 0 — Repository foundation: structure, docs, GitHub repo, CI directories.
- Epic 1 — Product definition: `docs/product/` (requirements, personas, learning philosophy, metrics, risks); CONTRIBUTING.md.
- Epic 2 — System architecture: `ARCHITECTURE.md`; `docs/architecture/` (application, Flutter, Firebase, offline/errors/logging); `docs/security/`; ADRs 0001–0004 (stack, Riverpod+go_router, admin panel same codebase, offline strategy).
- Epic 3 — Database design: `docs/database/` (schema, rules/validation strategy, indexes/migration); deployable `backend/firestore.rules`, `backend/storage.rules`, `backend/firestore.indexes.json`; ADR-0005.
- Epic 4 (code) — Cloud Functions in TypeScript (compile-verified), `firebase.json`, admin bootstrap script, Firebase setup runbook (`docs/deployment/01-firebase-setup.md`).
- Epics 5–9 — Flutter app in `app/flutter/` (Flutter 3.44.5, Riverpod 3, go_router 16): auth (demo), dashboard with stats/weak topics/history, practice with immediate feedback/explanations/bookmarks/review-incorrect, timed mock exams with scoring and per-question review, search, settings (theme, sign-out, delete account). Runs against in-memory demo repositories (ADR-0006). Verified: `flutter analyze` clean, 11 tests green, all flows driven in browser (light + dark).
- CI workflow `.github/workflows/ci.yml` (format, analyze, test, web build + functions build).
- Epic 10 V1 slice — Content Studio at `/admin` (ADR-0007): overview/stats, exam settings editor, question management (search, status filter, editor, archive, version bump), bulk import pipeline (CSV/JSON with validation report, duplicate detection, topic mapping, approval step), content-pack export/import. Question model extended (difficulty, tags, status, version, author, subtopic, learning objective, references). Verified: analyze clean, 21 tests green, full import flow driven in browser (validation errors block, clean rows import, learner sees published content).

- Epic 13 — Adaptive learning engine (ADR-0008): pure-Dart module `lib/adaptive/` (learner model, knowledge graph with lapse propagation, replaceable spaced-repetition scheduler, confidence model, adaptive selector, readiness/pass probability, study plans, learning DNA); AI service interfaces (`lib/domain/ai_services.dart`, no providers yet); wired into practice/mock flows; dashboard readiness card + adaptive session entry. Verified: analyze clean, 41 tests green, engine driven live in browser (readiness 0%→36%, plan reprioritized to weak topics after wrong answers). Schema extension: `docs/database/04-adaptive-schema.md`.

## In Progress

- Epic 4 (deploy) — BLOCKED on human: `firebase login`, project creation, deploy. Runbook: `docs/deployment/01-firebase-setup.md`.

## Next

- Epic 14 — Firebase production integration: after human runbook (`docs/deployment/01-firebase-setup.md`), implement Firestore repositories (incl. `LearnerModelRepository`) behind unchanged interfaces; swap = provider bindings only.
- Content Studio full spec remainder (`docs/product/07`); admin analytics dashboards.
- Deferred debt (ADR-0006/0007/0008): localization, widget/integration tests, per-question exam timing, SM-2/FSRS scheduler.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- No application code yet (starts Epic 4/5).
- `app/`, `backend/`, `cloud_functions/`, `tests/` are placeholders.
