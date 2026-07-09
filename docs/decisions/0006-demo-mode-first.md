# ADR-0006: Ship App Against In-Memory Demo Repositories First

**Status:** Accepted — 2026-07-09

## Context

Epic 4 deploy (Firebase project creation, `firebase login`) requires interactive human steps not yet performed. Epics 5–9 (Flutter app) would otherwise be blocked, and the app could not be previewed or tested.

## Decision

Implement the full learner app against in-memory implementations (`lib/infrastructure/demo_repositories.dart`) of the domain repository interfaces, with seeded driver's license content (`demo_data.dart`). Firestore implementations replace them behind the same interfaces once Firebase projects exist; the swap point is three providers in `lib/presentation/providers.dart`.

## Consequences

- App fully functional and previewable today; domain/application/presentation layers are final, not throwaway.
- Data does not persist across page reloads (in-memory) — acceptable for demo mode, resolved by the Firestore swap.
- Deliberate deferrals recorded as debt: localization scaffolding (strings currently inline English), admin panel screens (Epic 10), Firebase packages not yet in pubspec (added with the swap to avoid dead weight).
- Demo question bank doubles as fixture data for tests.
