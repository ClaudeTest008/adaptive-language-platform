# Security Rules and Validation

Live rules: [`backend/firestore.rules`](../../backend/firestore.rules), [`backend/storage.rules`](../../backend/storage.rules). This document explains the strategy; the files are the source of truth.

## Strategy

- Default deny. Explicit allow per collection.
- `isSignedIn()`, `isOwner(uid)`, `isAdmin()` (custom claim) helper functions.
- Content collections (`categories`, `countries`, `exams`, `topics`, `questions`): read for signed-in users **only when `published == true`** (admins read all); write admin-only with shape validation.
- User-owned data (`/users/{uid}/**`): owner read/write; attempts create-only (immutable history); admins read profiles for user management.
- `questionStats`: admin read; client writes denied (function uses Admin SDK, bypasses rules).
- Every write validates: required fields present, correct types, value ranges (e.g. `correctIndex` within `answers` bounds, `answers.size() >= 2 && <= 6`), no unexpected field creep on user profile.

## Validation Layers

| Layer | Validates | Why |
|-------|-----------|-----|
| Admin panel forms | UX-level: required fields, explanation non-empty, image size | fast feedback |
| Security rules | shape, types, ranges, ownership, role | trust boundary — the only layer that counts |
| Cloud Functions | cross-document invariants (account deletion completeness) | rules can't span documents |

## Rule Testing

Rules tested with `@firebase/rules-unit-testing` against the Firestore emulator (test suite lands with Epic 4 backend foundation; CI wiring in Epic 12). Minimum cases: anonymous denied everywhere; user cannot read unpublished content; user cannot write content; user cannot read/write another user's data; user cannot update an attempt; non-admin cannot get admin claim benefit; admin content write with invalid shape rejected.
