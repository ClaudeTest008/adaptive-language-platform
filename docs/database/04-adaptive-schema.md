# Firestore Schema Extension — Adaptive Platform (deploys with Epic 4)

Extends `01-firestore-schema.md`. These collections land together with the Firestore repository implementations; rules/indexes deltas listed below are added to `backend/firestore.rules` / `firestore.indexes.json` at that time.

## New Collections

### `/users/{uid}/learnerModel/{examId}`
One document per exam — the serialized `LearnerModel` aggregates:
`{totalAnswered, totalCorrect, mockExamScores: number[], studyDays: string[], updatedAt}`.

### `/users/{uid}/learnerModel/{examId}/concepts/{conceptId}`
Serialized `ConceptStats`: `{attempts, correct, streak, lapses, mastery, avgResponseSeconds, intervalDays, lastAnsweredAt, nextReviewAt}`.
Query: review queue = `concepts where nextReviewAt <= now orderBy nextReviewAt` (composite index).

### `/conceptGraph/{examId}` (admin-written)
Authored graph overrides: `{nodes: [{id, name, type, prerequisites[], related[], followUps[]}]}`. Derived graph (from topics/tags) is computed client-side; this document adds explicit curriculum edges when Content Studio's graph editor ships.

### `/questionVersions/{questionId}/versions/{version}` (admin-written)
Full question snapshot per version — enables rollback and historical attempt integrity. Written by Content Studio on every publish.

### `/importJobs/{jobId}` (admin-written)
Import analytics: `{startedAt, format, rowsTotal, imported, rejected, duplicateCount, durationMs, author}`.

### `/contentPacks/{packId}` (admin-written)
Marketplace/licensing groundwork: pack metadata + Storage path of the pack JSON.

### Multi-tenancy collections (ADR-0012, rules live + emulator-tested)

- `/orgs/{orgId}` — `{name, brandColorHex?, logoPath?}`; members read, platform ops write.
- `/orgs/{orgId}/members/{uid}` — `{role: owner|admin|editor|member}`; owners/admins manage; role whitelist rule-validated.
- `/orgs/{orgId}/questions/{id}` — org-private library, same shape rules as global questions; editors+ write.
- `/orgs/{orgId}/analytics/{doc}` — members read, Admin SDK writes only.
- `/libraries/{libId}` — `{name, scope: global|official|marketplace|organization|private, parentId?}`; questions live under the owning library; resolution client/worker-side (`resolveLibrary`).

### Content Intelligence collections (ADR-0011)

- `/documents/{docId}` (admin): source documents — `{title, format, storagePath, uploadedBy, uploadedAt, version}`; content bytes in Storage.
- `/extractionJobs/{jobId}` (worker-written): document processing state — `{docId, stage: uploaded|extracted|generated|validated, chapters, opportunities, failures, retries, startedAt, finishedAt}`.
- `/questionCandidates/{candId}` (admin/worker): serialized `QuestionCandidate` — `{question: {...}, source: import|document|ai, sourceExcerpt, quality: {score, issues[]}, createdAt}`. Admin read/write; never learner-visible (no learner read rule at all).
- Provenance: candidates and questions carry `author` (`ai:<provider>` for generated content) and `sourceExcerpt`; approval history is reconstructable from question versions.

### `/auditLogs/{logId}` (Admin SDK-written)
Content Studio audit trail: `{action, questionId?, actorUid, at, detail}`. Written server-side (function wrapper) so clients cannot forge entries; V2 slice records equivalent data in question versions + import jobs.

## Content Workflow Delta (ADR-0009)

`ContentStatus` is now `draft | review | approved | published | archived`. **Questions rule change:** learner read gate becomes `resource.data.status == 'published'` (replaces the `published` bool from the Epic 3 draft rules); admin writes validate `status in ['draft','review','approved','published','archived']`. Version snapshots: `questionVersions/{questionId}/versions/{version}` written in the same batch as every question upsert; version documents are immutable (`allow update, delete: if false`).

## Rules Deltas (strategy)

- `learnerModel/**`: owner read/write, shape-validated (numeric ranges, no field creep); admins no access (learner privacy).
- `conceptGraph`, `questionVersions`, `importJobs`, `contentPacks`: admin write with shape validation; `conceptGraph` readable by signed-in users; the rest admin-read only.

## Index Deltas

| Collection group | Fields | Serves |
|---|---|---|
| concepts | nextReviewAt ASC | review queue |
| versions | (auto single-field) | version history |
| importJobs | startedAt DESC | admin analytics |

## Migration

Additive only — no existing documents change shape. Learner models build from scratch per user (attempt history is not backfilled; documented trade-off: model warms up within one session).
