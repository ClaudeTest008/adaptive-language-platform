# Offline Strategy, Error Handling, Logging

## Offline Strategy (ADR-0004)

"Offline-friendly", not offline-first.

- Firestore offline persistence enabled on all platforms (default on mobile; enabled for web).
- Previously fetched questions, bookmarks, and attempts readable offline from cache.
- Writes (answers, attempts, bookmarks) queue automatically via Firestore and sync when connectivity returns.
- Practice mode works fully on cached questions. Mock exams require connectivity to start (fresh random question set); an in-progress mock exam survives connectivity loss — submission queues.
- No custom sync engine, no local database (Isar/Drift/SQLite) in V1. Firestore's cache covers the requirement; a local DB is the upgrade path if true offline-first becomes a requirement.
- UI: subtle offline banner; features that need connectivity (login, mock exam start, admin) show a clear message instead of failing silently.

## Error Handling

Single pipeline, one direction:

```
FirebaseException → (infrastructure mapper) → Failure → (use case Result) → controller → user message
```

- Sealed `Failure` types in domain; infrastructure maps SDK exceptions to them in one mapper per repository.
- Use cases return `Result<T, Failure>`; no exceptions cross layer boundaries.
- Controllers translate failures to localized user messages; every error surface offers retry where retry makes sense.
- Programming errors (assertions, null violations) are NOT converted to failures — they crash in dev and reach Crashlytics in prod. Failures are for expected conditions only.

## Logging

- `AppLogger` in `core/logging/`: `debug`, `info`, `warn`, `error(err, stack)`.
- Dev: pretty console output. Prod: `warn`/`error` become Crashlytics breadcrumbs/non-fatals; `debug`/`info` dropped.
- No third-party logging package unless a concrete need appears.
- Never log PII, tokens, or credentials.
