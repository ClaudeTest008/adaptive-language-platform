# Architecture Decision Records

One file per decision: `NNNN-title.md`. Statuses: Proposed, Accepted, Superseded (link successor).

ADRs 0001–0013 are inherited from the exam-platform lineage and remain binding for the Adaptive Learning Core. ADR-0014 onward are Adaptive Language Platform decisions.

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-flutter-firebase-stack.md) | Flutter + Firebase stack | Accepted |
| [0002](0002-riverpod-state-di-gorouter.md) | Riverpod for state + DI, go_router | Accepted |
| [0003](0003-admin-panel-same-codebase.md) | Admin panel in same Flutter codebase | Accepted |
| [0004](0004-offline-firestore-persistence.md) | Offline via Firestore persistence only | Accepted |
| [0005](0005-denormalized-questions-client-scoring.md) | Denormalized questions, client-side scoring | Accepted |
| [0006](0006-demo-mode-first.md) | App ships against in-memory demo repositories first | Accepted |
| [0007](0007-content-studio-v1-slice.md) | Content Studio V1 slice, client-side import pipeline | Accepted |
| [0008](0008-adaptive-learning-engine.md) | Adaptive learning engine as pure-Dart module; AI interfaces; Firebase swap deferred | Accepted |
| [0009](0009-content-studio-v2-versioning.md) | Content Studio V2: 5-state workflow, append-only versioning, bulk ops, import analytics | Accepted |
| [0010](0010-production-readiness.md) | Rules tested in CI via emulator; AI orchestration over single provider seam; V3 slice | Accepted |
| [0011](0011-content-intelligence-platform.md) | Content Intelligence: review-queue ingestion, chunked large imports, quality engine, document processing | Accepted |
| [0012](0012-multi-tenancy-and-libraries.md) | Multi-tenancy (rules-enforced isolation), library inheritance, curriculum hierarchy | Accepted |
| [0013](0013-workers-search-notifications.md) | Worker contracts, enterprise search seam, notification channels, KG expansion | Accepted |
| [0014](0014-fork-from-exam-platform.md) | Fork exam platform as Adaptive Language Platform; reuse core, extend never rewrite | Accepted |
