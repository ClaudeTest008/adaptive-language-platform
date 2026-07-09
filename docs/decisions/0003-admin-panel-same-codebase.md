# ADR-0003: Admin Panel in the Same Flutter Codebase (Web, Role-Gated)

**Status:** Accepted — 2026-07-08

## Context

V1 needs a simple web admin panel (exam/question/image/user CRUD + basic analytics). Options: separate web app (React/Vue), separate Flutter project, or routes inside the existing Flutter app.

## Decision

Admin panel lives in the same Flutter app under `/admin/*` routes, deployed as the web build, gated by the `admin` custom claim (UI) and Firestore rules (enforcement).

## Consequences

- Zero duplication: reuses auth, models, repositories, theme, DI.
- One codebase, one CI pipeline, one deployment for V1.
- Ships fastest; admin CRUD is well within Flutter web capability (R6).
- If admin needs outgrow Flutter web (heavy tables, rich text), the panel can be extracted later — repositories and rules are shared assets, only presentation would be rebuilt.
- Admin code ships inside mobile binaries (tree-shaking limits, routes unreachable without claim) — acceptable size cost for V1.

## Alternatives Considered

- Separate React admin: second stack, duplicated models/auth — rejected for V1.
- Firebase console as admin: unusable by non-technical admins, no validation — rejected.
