# ADR-0011: Content Intelligence Platform — Ingestion, Quality, Review Queue

**Status:** Accepted — 2026-07-09

Covers four requested decisions: content ingestion architecture, AI generation workflow, document processing strategy, large-import scaling strategy.

## 1. Content ingestion architecture

Everything ingested (large imports, documents, AI generation) produces **`QuestionCandidate`s in a review queue**, never library questions. The pipeline is:

```
source → validation (import pipeline) → quality scoring (deterministic)
       → candidate queue → human review → approved question → publish
```

One path, three entrances. Approval upserts a question with status `approved` (existing versioned workflow); publish stays a separate deliberate step. Provenance travels with the candidate (`CandidateSource.import|document|ai`, source excerpt, author).

## 2. Large-import scaling strategy

`runLargeImport` (application layer): single-pass parse/validate/dedupe (linear, fast even at 10k rows), then **chunked persistence** with a progress stream, yielding to the event loop between chunks — the UI never blocks. Failure emits a **checkpoint** (next chunk index + saved candidate ids); resuming from it completes without duplicates; **rollback** removes exactly the candidates a partial run saved. Verified by tests at 10,000 rows (2-minute timeout, passes in ~seconds).

Scale ceiling: in-app processing is bounded by browser/device memory (~50k rows). The 100k+ path is the same stage contract in Cloud Functions workers consuming an upload queue (Storage upload → Firestore job doc → worker fan-out) — deferred with Firebase (same gate as Epics 14/16); job schema already defined below.

## 3. Document processing strategy

`document_ingestion.dart`: format-specific text extraction (TXT passthrough, HTML tag/script stripping with heading preservation) → chapter detection (heading heuristics: markdown markers, "Chapter N", numbered sections, ALL-CAPS titles) → per-chapter **question opportunities** (fact-dense sentence detection: rule/definition signals, numbers). Chapters become topic candidates for the knowledge graph; opportunities become AI-generation inputs. Deterministic and tested. PDF/DOCX/scans: binary parsers + OCR are adapters behind the same `extractText` entry point, landing with the Storage upload pipeline.

## 4. AI generation workflow

`AiOrchestrator` now implements `AiDocumentExtractor`: source text in → question rows out **in the import-pipeline column contract** (answerA..D, correct, explanation, sourceExcerpt) — extracted content flows through the identical validation/dedup/quality/review path as human imports. Prompt constrains generation to facts present in the source; the grounding excerpt rides along for side-by-side review. Structural guarantee unchanged: AI output cannot reach learners without passing human approval (`AI Draft → Review → Approved → Published`).

## 5. Content quality engine

Deterministic scorer (`quality_engine.dart`), no AI dependency: clarity (length bounds, prompt form), ambiguity (negative phrasing, all/none-of-the-above), distractor quality (duplicates, length imbalance, option count), explanation quality (length, answer-echo), near-duplicate probability (token Jaccard vs non-archived content). Produces per-question `QualityReport` (score + named issues) shown in the Review tab, sorted worst-first so reviewer attention goes where it matters. AI review supplements when a provider is bound.

## Deferred (blockers named)

Cloud Functions worker fleet + upload queue (Firebase), PDF/DOCX/OCR parsers (binary deps + Storage), Excel (.xlsx) parsing (same), institution libraries/permissions (business pass), per-stage resource-usage metrics (workers), search index update stage (external engine per docs/architecture/05).
