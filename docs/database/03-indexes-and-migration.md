# Indexes and Migration Strategy

## Indexes

Single-field indexes are automatic. Composite indexes (declared in [`backend/firestore.indexes.json`](../../backend/firestore.indexes.json)):

| Collection | Fields | Serves |
|------------|--------|--------|
| questions | examId ASC, published ASC, topicId ASC | practice by topic |
| questions | examId ASC, published ASC, updatedAt DESC | admin list, full pool fetch |
| attempts (collection group not needed — per-user subcollection) | examId ASC, completedAt DESC | dashboard history |
| incorrect | examId ASC, lastWrongAt DESC | review queue |

Add indexes only when a query demands one (deploy error tells you); this file and the JSON stay in sync.

## Migration Strategy

Firestore is schemaless — "migration" means document shape evolution.

1. **Schema version field is NOT stored per document.** Instead, readers are tolerant: DTO `fromFirestore` treats missing new fields as defaults. Backward-compatible additions (new optional field) need no migration.
2. **Breaking changes** (rename, type change, restructure) require:
   - an ADR,
   - a one-off migration script in `scripts/migrations/NNN-description.ts` (Admin SDK, batched writes, idempotent),
   - rules updated to accept both shapes during rollout, tightened after.
3. **Order of deployment for breaking changes:** deploy tolerant readers (app) → run migration script → tighten rules → remove tolerance in next release.
4. **Content vs user data:** content migrations may rewrite in place (admin-owned); user-data migrations must be idempotent and resumable (script records progress in `/migrations/{id}`).
5. Multi-language readiness is pre-built: all display strings are `map<lang,string>` from V1 — adding a language is content work, not migration.

## Cost Notes

- Question fetch dominates reads. One practice session = 1 pool query (cached thereafter by offline persistence). Mock exam = reuse cached pool where fresh enough; pool re-fetched per app session at most.
- `topicStats` incremental counters avoid re-aggregating attempts on every dashboard view.
- `questionStats` aggregated daily by function, not on-demand.
