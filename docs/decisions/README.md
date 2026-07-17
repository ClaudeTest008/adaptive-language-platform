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
| [0015](0015-language-domain-model.md) | Language domain model: 11-tier hierarchy, typed relations projected onto core graph, signals beside LearnerModel, curricula as JSON | Accepted |
| [0016](0016-misconception-engine-and-signal-tracking.md) | Misconception engine (graph-authorized detection, log separate from mistakes), EWMA signal tracking, core engine reused via projection, showcase UI | Accepted |
| [0017](0017-exercise-generation.md) | Exercises derived from curriculum data (deterministic, focus-first); lineage-walking detection; diacritic-preserving answer checks | Accepted |
| [0018](0018-ai-tutor-foundation.md) | AI tutor foundation: TutorContext snapshot, six mode contracts, output validation with grounding, provider-blind over AiChatModel | Accepted |
| [0019](0019-language-first-navigation.md) | Language-first navigation: Language Lab at `/`, exam routes retired, multi-language selector, per-language demo state, immersion theme | Accepted |
| [0020](0020-stories-speaking-voice.md) | Short stories (data), speaking practice (pronunciation → signals), tutor voice; speech behind a provider-blind seam | Accepted |
| [0021](0021-bottom-nav-shell.md) | Bottom NavigationBar shell (Lab/Stories/Speaking/Tutor); FAB removed | Accepted |
| [0022](0022-daily-lesson-engine.md) | Daily lesson engine: weighted time-budgeted blocks from DNA + spaced repetition + weak areas + pronunciation + stories; per-block reason + launchable activity | Accepted |
| [0023](0023-conversation-engine.md) | Conversation engine: scenario-driven multi-turn dialogue, target-vocab steering, conversationAbility signal; sentence-chunked prosodic TTS | Accepted |
| [0024](0024-pronunciation-listening.md) | Phoneme-aware pronunciation scoring + per-word feedback, listening-recognition exercise + signal, speech-signal-weighted lessons, prosodic TTS, premium UI pass | Accepted |
| [0025](0025-content-ingestion.md) | Language content ingestion: pasted-text extractor (vocab/phrases/sentences/idioms/culture) mapped to concepts, human review queue, admin Content Studio; keyboard cleanup | Accepted |
| [0026](0026-content-merge-goals.md) | Approved content merges into live curriculum/stories; learner goals (minutes + target level) drive the lesson engine; production checklist | Accepted |
