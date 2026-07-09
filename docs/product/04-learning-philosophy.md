# Learning Philosophy

The platform teaches understanding, not answer memorization. V1 implements the simplest evidence-based mechanics; the data captured by V1 is deliberately shaped so future adaptive/AI features can build on it without schema rework.

## Principles Applied in V1

| Principle | V1 Implementation |
|-----------|-------------------|
| Active recall / retrieval practice | All studying is question-answering; no passive reading mode |
| Immediate feedback | Correct/incorrect shown instantly after each practice answer |
| Explanation-based learning | Every question carries a written explanation, always shown after answering |
| Interleaved practice | "All topics" practice mixes topics; mock exams randomize across topics |
| Progressive mastery | Per-topic accuracy tracked; weak topics surfaced on the dashboard |
| Weak topic identification | Topics under an accuracy threshold flagged and directly practicable |
| Spaced exposure (lightweight) | Review-incorrect sessions re-expose missed questions; full spaced-repetition scheduling deferred |

## Deliberately Deferred (architecture-ready, not built)

- **Adaptive question selection** — V1 records per-question attempt history (question id, correctness, timestamp, duration), which is the exact input an adaptive scheduler needs.
- **Knowledge graph learning** — questions carry topic references; topics are first-class documents so concept relationships can be added later.
- **AI tutor / AI explanations / AI study plans** — explanation field and attempt history give future AI features their grounding data.
- **Spaced repetition scheduling** — attempt timestamps are stored; a scheduler can be added without new data collection.

## Design Consequences

1. A question is never shown without an explanation available.
2. Every answer event is persisted with correctness, timestamp, and duration — this is the platform's most valuable long-term asset.
3. Topics are database entities, not string labels.
