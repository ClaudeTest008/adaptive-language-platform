# ADR-0009: Content Studio V2 — Versioning Workflow, Bulk Operations, Import Analytics; Firebase Still Docs-Only

**Status:** Accepted — 2026-07-09

## Context

Epic 14 spec: integrate Firebase if projects exist, otherwise stop before unverifiable code and complete every artifact so integration becomes a provider swap. Firebase CLI/login still absent on this machine — the spec's own gate applies. Content Studio V2 and adaptive persistence contracts are implementable and verifiable now.

## Decisions

1. **Five-state content workflow**: `draft → review → approved → published → archived` (additive extension of the enum; persisted by name so no migration). Learners see `published` only — enforced in the repository and covered by tests. Production enforcement is the Firestore rules delta (`status == 'published'` replaces the earlier `published` bool — documented in docs/database/04).
2. **Full version history, never overwrite**: every upsert snapshots the prior version (in-memory today, `questionVersions/{id}/versions/{n}` subcollection in Firestore). **Rollback restores old content as a NEW version** — history is append-only, which also preserves historical attempt integrity (attempts reference question id + version).
3. **Bulk operations** (publish / archive / tag) route through the same versioned upsert as single edits — one code path, no bypass.
4. **Import analytics**: every approved import records an `ImportJob` (rows, imported, rejected, duplicates, duration, author); pipeline tags duplicate issues explicitly. History visible in the Import tab.
5. **LearnerModel JSON codec** (`lib/adaptive/codec.dart`) is the frozen serialization contract for Firestore `learnerModel` documents — round-trip tested. The Firestore `LearnerModelRepository` becomes a thin document mapper.
6. **AI interfaces expanded** (still zero implementations): OCR, content reviewer (quality score + improvement suggestions), metadata generator (topic classification, learning-objective detection, difficulty, tags). All output remains admin-approval gated.

## Deferred (explicitly, with reasons)

- **Excel (.xlsx) import + file upload dialogs + image pipeline** — require new dependencies and Firebase Storage; land with Epic 14 implementation so upload/storage/validation ship as one verified unit.
- **Scheduled publishing** — needs a trusted clock trigger (Cloud Function cron); field design ready (`publishAt`), lands with functions deploy.
- **Review-workflow role separation** (author vs reviewer vs approver) — needs real user roles beyond the single admin claim; V2 slice exposes the states, not per-role permissions.
- **Question usage/accuracy analytics** — data source is `questionStats` (aggregation function), live after Firebase deploy.
- **Marketplace/white-label/institution packs** — content-pack format already portable; licensing metadata deferred to a business-requirements pass.

## Consequences

- Editors get version history, rollback, bulk operations, workflow states and import analytics today, demo mode.
- The Firestore swap surface is now: five repository implementations + rules/index deltas — all contracts frozen and documented in `docs/deployment/02-firestore-swap-guide.md`.
