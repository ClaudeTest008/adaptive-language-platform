# ADR-0022: Daily Personalized Lesson Engine

**Status:** Accepted
**Date:** 2026-07-17

## Context

`lesson.dart` was a Phase-2 stopgap (`previewDailyLesson`): repair block + two weak skills + a conversation tail, mastery-only. Phase 4 needs a real engine that plans from the whole learner picture — Learning DNA, spaced repetition, weak areas, pronunciation, goals, past performance — across every activity the app now has (practice, speaking, story, tutor).

## Decision

1. **`buildDailyLesson` replaces `previewDailyLesson`** (`lib/language/lesson.dart`, pure Dart). It builds candidate blocks in priority order, then a weighted allocator distributes the available minutes so the total always equals the budget, each block ≥5 min, lowest-priority blocks dropped when time is short.
2. **Candidate sources, in priority order:** misconception repair (always first), spaced-repetition reviews (concepts the core scheduler flags `isDue`), weakest skills below competence, low pronunciation-confidence concepts (→ speaking), a story that best overlaps today's focus concepts, and a conversation tail. Each block carries a plain-language **`reason`** — the personalization made visible — and a **`LessonActivity`** (practice / speaking / story / tutor) the UI launches.
3. **Learning DNA shapes weights, not just content:** `repeatsMistakes` boosts the repair share; `benefitsFromRepetition` boosts reviews; `fastResponder` boosts pronunciation/story; `strugglesUnderTimePressure` caps the plan to fewer, longer blocks. Past performance (`recentAccuracy`) and available time feed in as inputs.
4. **The engine stays pure — no core import.** The provider computes `dueConceptIds` from the core `ConceptStats` (`isDue`/lapses) and passes primitive inputs; lesson.dart reads only language-layer types. The core engine is untouched.
5. **Tappable blocks** dispatch by activity: practice → focused practice route, speaking → Speaking tab with a focused drill, story → the reader, tutor → the Tutor tab. The old standalone story-recommendation card is removed — the plan now owns the story block.

## Consequences

- Today's Plan is genuinely personal and self-explaining; each block says why it's there and starts the right activity in one tap.
- Pronunciation and story reading are first-class planned activities, not side features.
- `availableMinutes` is a provider (goal-derived) — a minutes selector can drive it later without touching the engine.
- Demo mode has no wall clock in its seeds, so the provider also treats lapsed concepts as "due" so spaced-repetition blocks appear in the showcase; real `nextReviewAt` scheduling takes over once sessions carry timestamps (Phase 8).
