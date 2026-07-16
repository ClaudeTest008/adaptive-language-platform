# ADR-0016: Misconception Engine, Signal Tracking, and Language Showcase UI

**Status:** Accepted
**Date:** 2026-07-16

## Context

Phase 2 needs (a) misconceptions detected and recorded separately from mistakes, (b) `LanguageConceptSignals` updated from answer events, and (c) screens that make the language platform visible in the running app. The core engine must stay untouched (ADR-0014); the language layer stays pure Dart (ADR-0015).

## Decision

1. **Misconception ≠ mistake.** `MisconceptionDetector` (pure, `lib/language/misconceptions.dart`) fires only on wrong answers and only when the graph authorizes attribution: `interferesWith`/`falseFriend` relations or `GrammarConceptNode.transferTraps`. A wrong answer without authored interference is a plain mistake and records nothing here. Detected misconceptions carry native language, interference source, pattern, teachable explanation, and related concept ids (pattern family = graph children + relatedTo/buildsOn neighbors). `MisconceptionLog` merges repeats by stable id (`conceptId|source`) and bumps occurrences.
2. **Signals update by EWMA beside the core model.** `LanguageConceptSignals.afterAnswer` (alpha 0.3) updates recall difficulty/speed, usage frequency; transfer-attributed errors increment `grammarTransferErrors` (never decays) and raise `nativeInterference` (decays on correct answers). `LanguageSignalsStore` keys by the same concept ids as the LearnerModel; the core model is never modified. New nullable signal `conversationAbility` reserved for Phase 5.
3. **Core engine reused, not extended, for language mastery.** `LanguageLearnerController` constructs the unchanged `LearnerEngine` with `languageGraph.toCoreGraph()`; every exercise answer becomes a core `AnswerEvent` over the node's `lineageConceptIds`. Mastery, lapse propagation and scheduling are inherited behavior verified by the existing 89 tests.
4. **Persistence seams land with their first producer** (per ADR-0015 consequence): `MisconceptionRepository` + `LanguageSignalsRepository` (load/save, matching `LearnerModelRepository` shape), in-memory demo implementations (ADR-0006). Firestore shapes already drafted in `docs/database/05-language-schema.md`.
5. **Showcase UI over a deterministic demo seed.** `/language` (skill mastery bars, misconception Teacher Notes, daily lesson preview) and `/language/concept/:id` (signals, graph relations, pattern family, live simulate buttons). The controller seeds a scripted demo learner (strong vocabulary, tener/ser-estar misconceptions) through the real engine on first build — the screens display genuine engine output, not fixtures. Demo state is in-memory and reseeds on app restart.
6. **Lesson preview is a Phase 4 stopgap** (`lib/language/lesson.dart`): deterministic time-budgeted blocks, misconception repair first (40% of budget), then two weakest skills, then conversation. The full Daily Lesson Engine (review schedule, goals, past performance) replaces it in Phase 4.

## Consequences

- Zero diffs under `lib/adaptive/` and `lib/ai/`; language layer imports the core only through `adaptive/graph.dart` (projection) and, in the controller, `adaptive/engine.dart`/`model.dart` — presentation-layer wiring, not core modification.
- The AI tutor (Phase 3) reads `MisconceptionLog` + signals as ready-made teaching context.
- Text-first exercise flows (multiple choice, fill-in-blank, translation…) remain open Phase 2 work — the engine path they will call (`recordAnswer`) is built and tested; the exercise UI is not.
- Demo seed reruns on every app start (no LearnerModel persistence for the language flow yet); acceptable for demo mode, revisit with Firestore swap.
