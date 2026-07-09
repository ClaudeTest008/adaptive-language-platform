# Firebase Architecture

## Services Used

| Service | Purpose |
|---------|---------|
| Authentication | Email/password auth, password reset, account deletion |
| Cloud Firestore | All application data (schema in `docs/database/`) |
| Cloud Functions | Privileged operations only (see below) |
| Storage | Question images, uploaded via admin panel |
| Analytics | Product metrics event catalog |
| Crashlytics | Crash and non-fatal error reporting (mobile) |

One Firebase project per environment: `dev` and `prod`. Config via `flutterfire configure` per environment (flavor-specific `firebase_options`). No staging until team size justifies it.

## Cloud Functions — Minimal Surface

Functions only where client + security rules cannot safely do the job:

| Function | Trigger | Purpose |
|----------|---------|---------|
| `setUserRole` | callable (admin-only) | Set/remove admin custom claim |
| `onUserCreate` | Auth trigger | Create Firestore user profile document |
| `deleteUserData` | callable (owner) | Account deletion: purge profile, attempts, bookmarks, then delete auth user |
| `aggregateQuestionStats` | scheduled (daily) | Roll up per-question accuracy for admin analytics |

Everything else (answering questions, attempts, bookmarks, admin CRUD) is direct Firestore access guarded by security rules — fewer moving parts, lower latency, lower cost. Add functions only when a rule cannot express the invariant.

Runtime: Node.js (TypeScript), `cloud_functions/` directory.

## Authorization

- Roles via Firebase Auth custom claims: `admin: true`.
- Client reads claim for UI gating; Firestore rules re-check `request.auth.token.admin == true` for every admin write. UI gating is convenience, rules are the boundary.

## Storage Layout

```
/question-images/{examId}/{questionId}/{filename}
```

- Write: admin only. Read: authenticated users.
- Images resized client-side before upload (max 1280 px) — no image-processing function needed in V1.

## Analytics Event Catalog (V1)

Typed wrapper in `core/analytics/`. Events: `sign_up`, `login`, `practice_session_start`, `question_answered` (params: topic_id, correct), `practice_session_end`, `mock_exam_start`, `mock_exam_complete` (params: score, passed), `bookmark_added`, `search_performed`, `weak_topic_viewed`. No PII in any event.

## Crashlytics

- `FlutterError.onError` and `PlatformDispatcher.onError` forwarded.
- Non-fatal: unexpected `Failure`s in infrastructure recorded with context breadcrumbs.
- Web: Crashlytics unsupported; web errors logged to console in V1 (revisit if web traffic matters).
