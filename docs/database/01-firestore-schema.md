# Firestore Schema

Design driver: model around access patterns, not normalization. Every screen should render from 1–2 queries.

## Collections

### `/categories/{categoryId}`
Exam category (V1: only `drivers-license`; future: motorcycle, medical, ...).

| Field | Type | Notes |
|-------|------|-------|
| name | map<lang,string> | localized display name, e.g. `{en: "Driver's License"}` |
| icon | string | material icon name |
| order | int | display order |
| published | bool | hidden until true |

### `/countries/{countryId}`
ISO 3166-1 alpha-2 id (e.g. `us`).

| Field | Type |
|-------|------|
| name | map<lang,string> |
| published | bool |

### `/exams/{examId}`
A concrete exam: category × country (× variant).

| Field | Type | Notes |
|-------|------|-------|
| categoryId | string | ref `/categories` |
| countryId | string | ref `/countries` |
| name | map<lang,string> | |
| questionCount | int | questions per mock exam |
| passThreshold | int | min correct to pass |
| timeLimitMinutes | int | mock exam timer |
| published | bool | |
| createdAt / updatedAt | timestamp | |

### `/exams/{examId}/topics/{topicId}`
Topics are first-class (learning philosophy: weak-topic tracking, future knowledge graph).

| Field | Type |
|-------|------|
| name | map<lang,string> |
| order | int |

### `/questions/{questionId}`
Top-level (not subcollection) so future cross-exam features can query globally; scoped by `examId` field.

| Field | Type | Notes |
|-------|------|-------|
| examId | string | |
| topicId | string | |
| text | map<lang,string> | |
| imagePath | string? | Storage path, null if none |
| answers | array<map<lang,string>> | 2–6 options, embedded |
| correctIndex | int | index into `answers` (see ADR-0005) |
| explanation | map<lang,string> | mandatory |
| published | bool | |
| createdAt / updatedAt | timestamp | |

### `/users/{uid}`
Created by `onUserCreate` function.

| Field | Type | Notes |
|-------|------|-------|
| displayName | string | |
| countryId | string? | |
| categoryId | string? | selected category |
| examId | string? | selected exam |
| settings | map | `{themeMode: "system", locale: "en"}` |
| disabled | bool | admin-set |
| createdAt | timestamp | |

Role is NOT stored here — roles live in Auth custom claims only (single source of truth).

### `/users/{uid}/bookmarks/{questionId}`
Existence = bookmarked. `{examId, createdAt}`.

### `/users/{uid}/incorrect/{questionId}`
Question currently in the "review incorrect" pool. Created on wrong answer, deleted when answered correctly in any later session. `{examId, topicId, timesWrong, lastWrongAt}`.

### `/users/{uid}/attempts/{attemptId}`
One per practice session or mock exam. Create-only (history immutable).

| Field | Type | Notes |
|-------|------|-------|
| type | string | `practice` \| `mock` \| `review` |
| examId | string | |
| startedAt / completedAt | timestamp | |
| durationSeconds | int | |
| score / total | int | |
| passed | bool? | mock only |
| answers | array<map> | `{questionId, topicId, selectedIndex, correct, seconds}` — the future adaptive-engine dataset |

### `/users/{uid}/topicStats/{topicId}`
Incrementally updated on each answer: `{examId, answered, correct, updatedAt}`. Weak topic = `correct/answered < 0.7` with `answered ≥ 10` (threshold in app config, not hard-coded in data).

### `/questionStats/{questionId}`
Written only by scheduled function `aggregateQuestionStats`: `{examId, answered, correct, updatedAt}`. Admin analytics; flags bad questions.

## Access Patterns → Queries

| Screen | Query |
|--------|-------|
| Practice (topic) | `questions where examId == X and topicId == Y and published == true` |
| Practice (all) / mock exam pool | `questions where examId == X and published == true` (client randomizes mock subset) |
| Review incorrect | `users/{uid}/incorrect where examId == X`, then fetch those questions (cached) |
| Bookmarks | `users/{uid}/bookmarks where examId == X` + cached questions |
| Dashboard | `users/{uid}/topicStats where examId == X` + last N `attempts orderBy completedAt desc` |
| Search | client-side over cached question set for the user's exam (bounded: hundreds of questions; no full-text service needed in V1) |
| Admin question list | `questions where examId == X orderBy updatedAt desc` |

## Relationships

All references are id-string fields (Firestore has no joins). Integrity enforced at write time by admin panel validation + security rule shape checks; no cascading deletes in V1 — deleting an exam requires deleting its questions first (admin panel enforces order).
