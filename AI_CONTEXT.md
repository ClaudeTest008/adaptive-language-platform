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

- Epics 0–3 complete (foundation, product definition, system architecture, database design).
- Next: Epic 4 — backend foundation. First step requires a human: `firebase login` + project creation, then deploy `backend/firestore.rules` / `storage.rules` / `firestore.indexes.json`, scaffold Cloud Functions (`setUserRole`, `onUserCreate`, `deleteUserData`, `aggregateQuestionStats`), write rules emulator tests.
- No application code yet.
- V1 scope: driver's license exam only; Flutter + Firebase; Clean Architecture (feature-first), Riverpod (state + DI), go_router. Admin panel = role-gated routes in same app. Requirements in `docs/product/`; architecture in `docs/architecture/`; schema in `docs/database/`; ADRs 0001–0005 in `docs/decisions/`.

## Key Conventions

- Documentation lives in `docs/` split by domain; root-level files are indexes and state.
- Decision records: `docs/decisions/NNNN-title.md`.
