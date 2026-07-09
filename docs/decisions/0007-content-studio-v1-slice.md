# ADR-0007: Content Studio Ships as In-App V1 Slice with Client-Side Import Pipeline

**Status:** Accepted — 2026-07-09

## Context

The Content Studio specification (docs/product/07) targets tens of thousands of questions, image pipelines, full versioning, and marketplace packs. Firebase is not yet deployed (Epic 4 human steps pending), and the full system spans several epics.

## Decision

1. Content Studio lives at `/admin` in the existing Flutter app (extends ADR-0003), against the same repository interfaces; a new `AdminRepository` interface covers content CRUD, import, and pack export/import.
2. The import pipeline runs client-side for V1 (parse → schema validation → question validation → duplicate detection → topic mapping → preview → approve → import). At scale, the same stage contract moves into a Cloud Function pipeline writing to Firestore in batches; the UI and report format stay.
3. Versioning V1 = monotonically increasing `version` field + draft/published/archived status; no overwrite of published content semantics is preserved by archive-instead-of-delete. Full version-history documents (one doc per version, rollback, per-attempt integrity) arrive with the Firestore implementation, where history is a subcollection.
4. Import formats V1: CSV and JSON (paste-in). Excel/upload/images deferred — same pipeline entry point.

## Consequences

- Admins get a working editor + validated bulk import today; nothing bypasses validation (spec's core invariant holds).
- Client-side pipeline caps practical batch size (~thousands, browser memory) — acceptable until Firestore lands; the stage contract is the scaling seam.
- `Question` gains optional metadata (difficulty, tags, subtopic, learning objective, references, status, version, author, timestamps) — additive, no migration.
- Demo mode grants every signed-in user admin (single-user demo); production gate = custom claim + Firestore rules (already written in Epic 3).
