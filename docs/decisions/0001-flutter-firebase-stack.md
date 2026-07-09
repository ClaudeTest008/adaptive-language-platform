# ADR-0001: Flutter + Firebase Stack

**Status:** Accepted — 2026-07-08

## Context

Cross-platform exam platform (Android, iOS, web) with a small team. Needs auth, document data, file storage, analytics, crash reporting, and occasional server-side logic without operating servers.

## Decision

Flutter for all clients; Firebase (Auth, Firestore, Cloud Functions, Storage, Analytics, Crashlytics) for the backend.

## Consequences

- One codebase for three platforms; one language (Dart) for app code.
- No server operations burden; pay-per-use pricing scales from zero.
- Vendor lock-in risk (R9) mitigated by Clean Architecture: Firebase confined to the infrastructure layer behind repository interfaces.
- Crashlytics unavailable on web — accepted for V1.
- Complex relational queries unavailable in Firestore — schema designed around access patterns instead (Epic 3).

## Alternatives Considered

- React Native + custom backend: two languages, server ops burden — rejected.
- Flutter + Supabase: relational model attractive, but weaker mobile offline story and less mature Flutter tooling at decision time — rejected for V1.
