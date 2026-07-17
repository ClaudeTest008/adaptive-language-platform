# ADR-0026: Content Merge into Live Curriculum + Learner Goals

**Status:** Accepted
**Date:** 2026-07-17

## Context

Phase 7 (ADR-0025) extracted content into a review queue but stopped at
approval — approved items went nowhere. Phase 8 closes that loop and adds
the learner-goals surface the lesson engine's `availableMinutes` was
already parameterized for. Firebase keys are unavailable, so this is the
demo-mode production slice: real logic, in-memory persistence.

## Decision

1. **Approved candidates merge into the live curriculum** (`lib/language/
   content_merge.dart`, pure Dart). `mergeApprovedContent(base, approved)`
   attaches approved, unmapped vocabulary and phrases/idioms as new
   `VocabularyConceptNode`/`PhraseNode`s under a synthesized
   `<lang>:<level>:vocabulary:ingested` domain — so they never collide
   with authored concepts, generate exercises like any other node, and
   feed the graph the core projection already consumes. `storyFromApproved`
   turns approved example sentences into a "From your content" story.
   Mapped candidates (already in the curriculum) and rejected ones never
   re-add. The base curriculum object is never mutated.
2. **A durable approved-content store** (`approvedContentProvider`, resets
   on language switch) is appended by the Content Studio on approve and
   removed on reject. `curriculumProvider` and `storiesProvider` watch it
   and fold the additions in — so ingestion is visible everywhere
   (practice, stories, plan) immediately. Only approved items flow; the
   review queue stays the gate.
3. **Learner goals** (`learnerGoalsProvider`: minutes/day + target CEFR
   level, in-memory). `availableMinutesProvider` now reads the goal, so
   the Daily Lesson Engine budgets to the learner's time; `storiesProvider`
   caps the queue at the target level (read ahead); the tutor's goal
   string reflects the target. A `/goals` screen (minutes slider + level
   chips) is reachable from the Lab app bar.
4. **Production checklist** (`PRODUCTION_CHECKLIST.md`) tracks the
   remaining launch work (persistence swap, real speech/AI providers, iOS
   parity, analytics), each item ready behind an existing seam.

## Consequences

- Ingestion is a full loop: paste → review → approve → practise/read the
  new material — all in-memory this session; the merge/goals logic is
  final and swaps to Firestore behind the same providers (Phase 8 infra).
- Ingested concepts live under one clearly-namespaced domain, keeping the
  authored curriculum clean and the additions easy to persist/migrate.
- Goals are session-scoped in demo mode; the surface and wiring are done,
  only the store swaps.
- The Adaptive Learning Core remains untouched — the merge only grows the
  language graph, which projects onto the core unchanged.
