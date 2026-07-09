# AI Context

This file is the permanent memory of the project for AI development sessions. Read it at the start of every session. Keep it accurate and short.

## What This Project Is

Adaptive exam preparation platform:

- Flutter client app (`app/flutter/`)
- Backend services (`backend/`)
- Serverless functions (`cloud_functions/`)
- AI-assisted adaptive learning engine (documented in `docs/learning-engine/` and `docs/ai/`)

## Rules for AI Sessions

1. Read `PROJECT_STATUS.md` and `TASKS.md` before starting work.
2. Complete one well-defined task at a time; do not start unrelated work.
3. Read only the documentation referenced by the current task.
4. Never recreate files that already exist; continue from the current state.
5. Record architectural decisions in `docs/decisions/` (one file per decision).
6. Update `PROJECT_STATUS.md`, `TASKS.md`, and `CHANGELOG.md` when a milestone or task completes.
7. Keep commits small and focused; report the commit hash after each commit.

## Current State

- Epics 0–3 complete; Epic 4 code complete (deploy pending human steps in `docs/deployment/01-firebase-setup.md`); Epics 5–9 complete in demo mode (ADR-0006).
- App: `app/flutter/` — Flutter 3.44.5 (SDK at `C:\Users\Admin\flutter`), Riverpod 3 (note: `StateProvider` needs `flutter_riverpod/legacy.dart` import; `AsyncValue.valueOrNull` is now `.value`), go_router 16. Repository interfaces in `lib/domain/repositories.dart`; demo implementations in `lib/infrastructure/`; swap point = three providers in `lib/presentation/providers.dart`.
- Backend code: `cloud_functions/src/index.ts` (4 functions), rules/indexes in `backend/`, deploy config `firebase.json`. CI: `.github/workflows/ci.yml`.
- Epic 10 V1 slice done: Content Studio at `/admin` (ADR-0007) — question CRUD + import pipeline (`lib/application/import_pipeline.dart`), content packs (`lib/infrastructure/content_pack.dart`), mutable content store serves ContentRepository + AdminRepository. Full spec: `docs/product/07-content-studio-requirements.md`.
- Next: Firebase deploy (human runbook), then Firestore repositories; Content Studio spec remainder per docs/product/07.
- V1 scope: driver's license exam only; Flutter + Firebase; Clean Architecture (feature-first), Riverpod (state + DI), go_router. Admin panel = role-gated routes in same app. Requirements in `docs/product/`; architecture in `docs/architecture/`; schema in `docs/database/`; ADRs 0001–0005 in `docs/decisions/`.

## Key Conventions

- Documentation lives in `docs/` split by domain; root-level files are indexes and state.
- Decision records: `docs/decisions/NNNN-title.md`.
