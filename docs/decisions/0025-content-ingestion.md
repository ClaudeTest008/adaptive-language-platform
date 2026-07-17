# ADR-0025: Language Content Ingestion + Keyboard/Input Cleanup

**Status:** Accepted
**Date:** 2026-07-17

## Context

The inherited Content Intelligence pipeline (ADR-0011) extracted exam questions from documents into a review queue. Phase 7 needs the same discipline for language material: paste target-language text, extract learnable elements, review, approve. Separately, users saw the Android keyboard's toolbar linger as a "floating bar" over practice screens.

## Decision

1. **Language content extractor** (`lib/language/ingestion.dart`, pure Dart): `ingestLanguageText(text, graph, languageCode)` returns an `IngestionResult` — estimated CEFR difficulty, topics, and `ContentCandidate`s across five kinds: vocabulary (content words by frequency), phrases (content-word bigrams), example sentences (learnable length), idioms (seed list matched by phrase or key noun, since idioms appear conjugated/split), cultural notes (keyword-flagged sentences). Each candidate maps to an existing curriculum concept id where the word/phrase is recognized, else is flagged "new". Deterministic.
2. **Human review queue** (same discipline as ADR-0011): `ContentReviewLog` (approved/rejected/pending) with a `ContentReviewRepository` seam (in-memory demo). Nothing enters the curriculum without approval; merging approved candidates into curriculum nodes / stories is the follow-on (Phase 8 persistence).
3. **Admin Content Studio** (`/content`, `LanguageContentScreen`): paste a passage (or "Use sample"), extract, and review candidates grouped by kind with mapped/new status and approve/reject actions. Reachable from a Language Lab app-bar icon shown only to admins (`authState.isAdmin`; demo mode makes every user admin, ADR-0007). Bottom nav stays at four tabs.
4. **Keyboard cleanup**: the "floating bar" was the system keyboard's toolbar appearing on field focus. No in-app floating element exists. Practice now unfocuses on submit and on advancing to the next item, so the keyboard never lingers over feedback or the next question — it reopens only when the learner taps a field. Voice/mic controls already sit at the bottom of the tutor input row and as the primary control in speaking.
5. **Content**: four new narrative stories (two A1, two A2) across markets, parks, trains, and a birthday fiesta.

## Consequences

- New material flows in through a reviewed pipeline: extract → preview → approve, mapped to the graph, never bypassing human sign-off.
- The extractor is a deterministic heuristic (frequency, seed idioms, keyword culture) — good enough to make ingestion useful offline; an AI extractor can later produce candidates through the same review queue (the `AiChatModel` seam is available).
- Approved candidates are recorded but not yet merged into the live curriculum/stories — that lands with Firestore persistence (Phase 8).
- A2 stories exist but surface only once the learner's recommended level reaches A2 (ADR-0020 level gating).
