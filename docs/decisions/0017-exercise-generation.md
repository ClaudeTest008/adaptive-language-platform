# ADR-0017: Exercises Derived from Curriculum Data

**Status:** Accepted
**Date:** 2026-07-16

## Context

Phase 2's remainder needs the five text-first exercise types (multiple choice, fill-in-the-blank, translation, sentence building, reading comprehension) producing real answer events. Authoring exercise content separately would duplicate what the curriculum already carries: vocabulary lemmas + translations, phrases + translations, example sentences + translations, all keyed by concept id.

## Decision

1. **Exercises are derived, not authored** (`lib/language/exercises.dart`, pure Dart). `generateExercises(graph, focusConceptIds, limit)` builds items from graph nodes: vocabulary → multiple choice (distractors = other vocab translations), phrase → translation, example sentence → fill-in-blank (longest word), sentence building (word bank), reading comprehension (meaning among other sentences' translations). Curriculum growth automatically grows the exercise pool.
2. **Deterministic**: shuffles are seeded by item id — same curriculum, same session; reproducible tests. Focus concepts (a repair block) sort first, so "Practice your weak spots" literally leads with them.
3. **Answer checking** normalizes case/spacing/final punctuation but **keeps diacritics** — producing "está" vs "esta" is a learning outcome, not noise.
4. **Detection walks the lineage.** `recordAnswer` runs the misconception detector over the node's full lineage (leaf-first): an error on "Tengo hambre" is evidence of the `tener-states` misconception even though the exercised node is a child sentence. Signals land on the answered concept plus any ancestor a misconception was attributed to. `recordAnswer` returns the detected misconceptions so exercise flows show teacher notes inline; it also awaits controller init so cold deep links into practice never drop events.
5. **Practice session** (`languagePracticeProvider` + `/language/practice`): sequential items, submission → real answer event (core engine, detector, signals), inline feedback (correct answer + teacher notes), animated progress + score summary. Dashboard CTA starts a session focused on the current repair block.

## Consequences

- Zero exercise content to maintain; es/en seeds gained three example sentences (data-only) to enrich the pool.
- Exercise variety is bounded by curriculum richness — thin topics produce few items; acceptable until Phase 7 content ingestion feeds the curriculum.
- Listening/speaking/pronunciation/conversation exercise types remain enum-only until their engines land (Phases 5–6).
- The demo seed still paints the dashboard on first launch; practice sessions now layer real learner events on top of it.
