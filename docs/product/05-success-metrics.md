# Success Metrics

## V1 Launch Criteria (engineering)

- All V1 functional requirements implemented and verified.
- Test suite green in CI; formatting and analyzer clean.
- Firestore security rules reviewed and tested.
- Production builds for Android, iOS, and web produced by CI.
- Documentation current (README, ARCHITECTURE, database docs, deployment docs).

## Product Metrics (post-launch, via Firebase Analytics)

| Metric | Definition | V1 Target |
|--------|------------|-----------|
| Activation | % of registered users answering ≥ 10 questions in first session | ≥ 50% |
| D7 retention | % of new users active 7 days after registration | ≥ 20% |
| Learning effect | Median accuracy improvement between a user's first and third mock exam | positive |
| Mock exam adoption | % of weekly-active users taking ≥ 1 mock exam per week | ≥ 30% |
| Stability | Crash-free sessions (Crashlytics) | ≥ 99.5% |
| Content health | Questions flagged by accuracy < 20% (likely bad question) reviewed by admin | 100% reviewed |

## Guardrails

- Question fetch latency p95 < 500 ms online.
- No decline in accessibility audit score between releases.
