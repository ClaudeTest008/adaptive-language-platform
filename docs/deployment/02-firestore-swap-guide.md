# Firestore Swap Guide (Epic 14 implementation runbook)

Prerequisite: `01-firebase-setup.md` completed (projects exist, rules/indexes/functions deployed). This document makes the production integration a mechanical provider swap. All interfaces and serialization contracts are frozen and tested.

## 1. Packages + config

```bash
cd app/flutter
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage firebase_analytics firebase_crashlytics
dart pub global activate flutterfire_cli
flutterfire configure --project=<dev-project>
```

`main.dart`: `await Firebase.initializeApp(...)` before `runApp`; enable Firestore persistence (`Settings(persistenceEnabled: true)` — web needs `enablePersistence()`).

## 2. Repository implementations (interfaces unchanged)

| Interface | Firestore mapping | Notes |
|---|---|---|
| `AuthRepository` | `FirebaseAuth` | `authStateChanges` maps `User` → `UserProfile`; `isAdmin` from `getIdTokenResult().claims['admin']`; `deleteAccount` calls `deleteUserData` callable |
| `ContentRepository` | `exams/{id}`, `exams/{id}/topics`, `questions where examId+status=='published'` | localized maps → pick locale, fallback `en` |
| `StudyRepository` | `users/{uid}/bookmarks|incorrect|attempts|topicStats` | writes queue offline automatically |
| `AdminRepository` | `questions` CRUD; versions to `questionVersions/{id}/versions/{n}` (batched write with the upsert); `importJobs`; bulk ops = `WriteBatch` chunks of ≤500 | rollback = read version doc, write as new version |
| `LearnerModelRepository` | `users/{uid}/learnerModel/{examId}` via `learnerModelToJson`/`fromJson` (`lib/adaptive/codec.dart`) | concepts inline map if <1 MB doc (24-topic exam: yes); split to subcollection at scale |

DI swap point — exactly three lines change in `lib/presentation/providers.dart`: `_contentStoreProvider`, `authRepositoryProvider`, `studyRepositoryProvider`, `learnerModelRepositoryProvider` bind Firestore classes instead of demo classes. UI untouched.

## 3. Sync & conflict strategy

- All user-owned documents are single-writer (one user, one device at a time is the norm) — **last-write-wins with server timestamps** is sufficient; no merge logic. `topicStats` uses `FieldValue.increment` so concurrent devices converge.
- Learner model saves debounce to once per answered question (current behavior) — acceptable write volume (~1 write/question); revisit with batching if cost data says otherwise.
- Offline: Firestore persistence covers reads; queued writes flush on reconnect (ADR-0004 unchanged).

## 4. Rules/index deltas to apply

Documented in `docs/database/04-adaptive-schema.md`: learner model collections, question versions, import jobs, audit log; **questions rule change: `resource.data.status == 'published'` replaces the `published` bool check** (model migrated to status enum in ADR-0007/0009). Add `status` field validation (allowed values list).

## 5. Migration scripts

`scripts/migrations/` (Admin SDK, idempotent, batched):
- `001-seed-content.ts` — import the demo content pack (`exportContentPack` output) into dev.
- `002-status-field.ts` — only if any docs were created with the old `published` bool: map `published:true→status:'published'`, else no-op.

## 6. Verification checklist (before claiming Epic 14 done)

- Rules emulator tests green (cases listed in `docs/database/02`).
- App against dev project: register → practice → adaptive session → mock exam → Content Studio edit/version/rollback/import — all flows re-verified in browser.
- Offline test: airplane-mode practice on cached content, reconnect, attempts synced.
- Crashlytics receives a forced test error; Analytics debug view shows event catalog.
- App Check enforced (Play Integrity / DeviceCheck / reCAPTCHA v3 web) in enforce mode on Firestore + Functions.
- Remote Config: weak-topic threshold + adaptive constants exposed as remote parameters with in-code defaults.
