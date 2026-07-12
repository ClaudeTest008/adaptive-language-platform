# ADR-0013: Background Workers, Enterprise Search, Notifications, Knowledge-Graph Expansion

**Status:** Accepted — 2026-07-09

## Background worker architecture (contracts fixed, deployment deferred)

Workers are Cloud Functions consuming Firestore job documents; **each wraps a stage contract that already exists and is tested in-app** — no redesign, no duplicate pipelines:

| Worker | Existing contract wrapped | Trigger |
|---|---|---|
| large-import | `runLargeImport` stages (parse→validate→chunk-save w/ checkpoint) | `importJobs` doc created w/ Storage path |
| document-processing | `ingestDocument` + `AiDocumentExtractor` | `extractionJobs` doc |
| ocr / image | `AiOcr` + image pipeline (docs/product/07) | Storage upload finalize |
| question-generation | `AiQuestionGenerator` → candidates | generation job doc |
| metadata-generation | `AiMetadataGenerator` | candidate created |
| kg-update | graph build (`buildKnowledgeGraph`) + authored overrides | content publish |
| analytics-aggregation | `aggregateQuestionStats` (exists in functions) + org rollups | scheduled |
| search-index | `SearchService` provider push | content publish |
| notification-delivery | `NotificationChannel` implementations | notification doc |

Checkpoints (`LargeImportCheckpoint`) map to job-doc progress fields; resume semantics identical. Deployment blocked on Firebase (same gate as Epics 14/16) — contracts are the deliverable.

## Enterprise search

`SearchService` interface (`search`, `findSimilar`) is the provider seam. `ClientSearchService` formalizes current in-memory search (questions/topics/learning objectives/import jobs; token-overlap ranking; similarity = existing quality-engine `textSimilarity`). External engines (full-text: Algolia/Typesense; semantic: embedding store) implement the same interface, fed by the search-index worker. Adoption trigger unchanged (docs/architecture/05: ~5k questions/exam or cross-exam search).

## Notifications

`NotificationChannel` (deliver) + `NotificationService` (fan-out) + typed `NotificationKind` catalog (study reminder, review due, exam countdown, adaptive recommendation, import completed, review requested, published, announcement). `InAppNotificationChannel` works today (inbox, tested); FCM/email/SMS/web-push are future channels behind the same interface — delivery infra unverifiable until Firebase. `buildStudyNotifications` derives learner notifications deterministically from adaptive outputs (plan + readiness) — tested.

## Knowledge-graph expansion

Incremental updates preserved: derived graph rebuilds from content (cheap, already incremental via `contentVersion`); authored edges live in `conceptGraph` overrides (docs/database/04); `AiKnowledgeGraphBuilder` interface proposes edges that are review-gated before entering overrides. Hierarchy concept ids (ADR-0012) slot into the same graph without engine changes.

## Scale fix shipped with this ADR

Import-pipeline question ids were `hash(text)` only — at 100k rows the stress test surfaced 4 hash collisions silently dropping rows. Ids now include the row number (`imp-<row>-<hash>`), deterministic per file (resume-stable). The 100k simulation is a permanent regression test.
