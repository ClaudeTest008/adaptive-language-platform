# ADR-0008: Adaptive Learning Engine as a Pure-Dart Module; Firebase Swap Still Deferred

**Status:** Accepted — 2026-07-09

## Context

The Production Learning Platform Foundation spec asks for (a) Firebase production integration and (b) an adaptive learning engine (learner model, knowledge graph, spaced repetition, confidence, readiness, study plans, learning DNA, AI foundations).

Firebase projects still do not exist — creation requires interactive `firebase login` (human step, runbook in `docs/deployment/01-firebase-setup.md`). Writing Firestore repositories that cannot be executed once this session would ship unverifiable code, violating the project's own verification rule. Ordering challenged accordingly: the engine is implemented first (fully testable, immediately live in demo mode); the Firebase swap remains a bounded, documented change.

## Decision

1. **Engine is a pure-Dart module** (`lib/adaptive/`): no Flutter, no Firebase, no I/O. Services exposed through interfaces; presentation touches it only via Riverpod providers.
2. **Learner model**: per-concept `ConceptStats` (attempts, streak, lapses, EWMA mastery, EWMA response time, review interval/date) + global aggregates (accuracy, mock scores, study days). Every answered question — practice and mock — emits an `AnswerEvent` through one translation point (`answerEventFor`).
3. **Knowledge graph**: concept nodes derived from content (topics → subtopics as follow-ups/prerequisites; tags relate topics). Questions reference concepts as `[topicId, sub:…, tag:…]`. Incorrect answers propagate a reduced-strength mastery penalty to graph-related concepts.
4. **Spaced repetition behind `ReviewScheduler`**: baseline `ExpandingIntervalScheduler` (grow ~2.2× on correct, cap 60 d, collapse on lapse). SM-2 / FSRS / ML replace it behind the same interface with zero application changes.
5. **Confidence model**: mastery-anchored score adjusted by streak, response speed, evidence volume, and lapse rate — correctness alone never suffices.
6. **Adaptive selection** (`QuestionSelector`): priority buckets — due reviews (most overdue first) > weak concepts (difficulty matched to mastery) > unseen > consolidation — with small jitter for session variety. Replaces random selection in the recommended practice flow.
7. **Readiness & study plan**: deterministic heuristics (documented in code with upgrade paths): coverage/mastery/retention blend, logistic pass probability, prioritized plan items with time estimates.
8. **Learning DNA**: traits recomputed from the model (fast responder, slow-but-accurate, low/high confidence, repeats mistakes, …), never stored as ground truth.
9. **AI foundations**: provider-independent interfaces only (`lib/domain/ai_services.dart`), resolved via DI (`AiServices.none` in V1). Any provider (Anthropic, OpenAI, Gemini, local) implements them without architecture changes; all AI output routes through the existing import/approval pipeline.
10. **Persistence seam**: `LearnerModelRepository` (in-memory now; Firestore `learnerModels/{uid}` per `docs/database/04-adaptive-schema.md`).

## Consequences

- Engine live in the app today (demo mode): adaptive sessions, readiness card, study plan — all verifiable.
- All heuristic constants are named and unit-tested; replacing any heuristic is a local change behind an interface.
- Mock exams feed the engine with session-average response times (per-question exam timing deferred — noted in code).
- Firebase integration remains the top of the backlog once projects exist; repository interfaces unchanged, swap = provider bindings only.
