# Security Architecture

## Principles

Least privilege, server-side enforcement, no secrets in client code, secure defaults.

## Trust Model

- Client is untrusted. All authorization enforced by Firestore security rules and (for privileged operations) Cloud Functions.
- Client-side role checks exist only for UX (hiding admin UI); never relied on for protection.

## Authentication

- Firebase Auth, email/password. Email verification encouraged but not blocking in V1.
- Password policy: Firebase default (min 6) raised to min 8 via Auth settings.
- Password reset via Firebase-managed email flow — no custom token handling.
- Account deletion (FR-7.3): `deleteUserData` callable function purges user data and deletes the auth account; only callable by the account owner.

## Authorization

| Role | Grant mechanism | Capabilities |
|------|-----------------|--------------|
| user (default) | Auth signup | Read published content; read/write own profile, attempts, bookmarks |
| admin | `admin: true` custom claim, set by `setUserRole` function | All user capabilities + content CRUD, user management, analytics |

- `setUserRole` callable only by existing admins; first admin bootstrapped manually via Firebase console/script (documented in deployment docs).
- Every admin-only Firestore/Storage rule checks `request.auth.token.admin == true`.

## Firestore Rules Strategy

Detailed rules ship with the schema (Epic 3). Strategy:

- Default deny; explicit allow per collection.
- Users read/write only documents keyed by their own `uid`.
- Content (exams, topics, questions) readable by authenticated users, writable only by admins.
- Rules validate document shape on write (required fields, types, value ranges) — validation at the trust boundary, not only in client code.
- Attempts are create-only for users (no editing history); statistics documents written by owner, shape-validated.
- Rules tested with the Firestore emulator in CI (Epic 11/12).

## Storage Rules

- `question-images/**`: read authenticated, write admin-only, content-type restricted to images, size-capped (≤ 2 MB).

## Data Protection & Privacy

- PII limited to: email, display name, country. No PII in analytics events or logs.
- Crashlytics reports scrubbed of user identifiers beyond Firebase installation id.
- Account deletion removes profile, attempts, bookmarks, stats (R8 mitigation).

## Dependency & Supply Chain

- Dependencies: Flutter/Firebase official packages + small vetted set (Riverpod, go_router, intl). Each new dependency requires justification in PR/commit.
- Dependabot enabled on GitHub for pub and npm (functions).

## Secrets

- No API secrets in the repository. Firebase client config is not secret (protected by rules), but service-account keys never enter the repo. CI secrets via GitHub Actions secrets.
