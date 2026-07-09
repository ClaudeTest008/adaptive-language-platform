# ADR-0004: Offline Strategy = Firestore Offline Persistence Only

**Status:** Accepted — 2026-07-08

## Context

Requirement is "offline-friendly where practical" (NFR-5), not offline-first. Users study in connectivity gaps (commutes). Options: Firestore built-in persistence, or a local database (Isar/Drift) with a custom sync layer.

## Decision

Use Firestore's built-in offline persistence exclusively. No local database, no custom sync engine in V1.

## Consequences

- Cached questions, bookmarks, and attempts work offline; queued writes sync automatically — meets NFR-5 with zero custom code.
- Mock exam start requires connectivity (fresh randomized set); in-progress exams survive disconnection; submissions queue.
- No conflict resolution needed: user-owned documents are single-writer.
- Ceiling: no guaranteed full-content offline download, no cross-device offline consistency. If offline-first becomes a requirement, add a local DB + explicit download feature as a new infrastructure implementation behind the same repository interfaces — no domain changes.

## Alternatives Considered

- Isar/Drift + sync layer: significant complexity, conflict handling, second source of truth — unjustified by NFR-5. Rejected for V1.
