# ADR-0002: Riverpod for State Management + DI, go_router for Routing

**Status:** Accepted — 2026-07-08

## Context

Clean Architecture requires dependency injection and predictable state management. Auth-dependent redirects and deep-linkable web routes (admin panel) require declarative routing.

## Decision

- **Riverpod** for both dependency injection (providers bind infrastructure implementations to domain interfaces) and presentation state (`Notifier`/`AsyncNotifier`).
- **go_router** for routing, with auth/admin redirect guards.

## Consequences

- One tool for DI + state: less machinery than bloc + get_it + injectable; compile-safe, test-friendly overrides.
- go_router is the Flutter-team-maintained standard; URL-based routing works on web out of the box (needed for admin panel deep links).
- Team must follow the discipline: controllers call use cases only; no repository access from widgets.

## Alternatives Considered

- bloc + get_it: more boilerplate per feature, second DI tool — rejected.
- Provider (classic): superseded by Riverpod — rejected.
- Navigator 2.0 raw: needless complexity — rejected.
