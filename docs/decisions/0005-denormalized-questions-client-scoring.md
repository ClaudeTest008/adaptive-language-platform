# ADR-0005: Denormalized Questions with Embedded Answers and Client-Side Scoring

**Status:** Accepted — 2026-07-08

## Context

Firestore charges per document read and has no joins. A question could be split across documents (question / answers / explanation) with the correct answer hidden server-side, requiring a Cloud Function round-trip to score each answer.

## Decision

1. Each question is one document embedding its answers, `correctIndex`, and explanation.
2. The client scores answers locally and shows immediate feedback.
3. All display strings are `map<lang,string>` from day one.

## Consequences

- One read per question; practice works offline from cache; feedback is instant (NFR-4) with zero function invocations.
- **Accepted trade-off:** the correct answer is technically visible to a client inspecting network traffic. This is a study app whose purpose is showing correct answers and explanations — cheating against oneself has no victim. Mock exam results are self-reported progress data, not certification. If results ever gate anything real (institutional use), scoring moves server-side as a new infrastructure implementation; domain layer unchanged.
- Multi-language content requires no future migration.
- Attempt history (per-question answer events) is create-only and stored per user — the future adaptive engine's dataset accumulates from V1 launch.

## Alternatives Considered

- Server-side scoring via callable function: +latency, +cost, breaks offline practice — rejected for V1.
- Separate answers subcollection: multiplies reads for zero V1 benefit — rejected.
