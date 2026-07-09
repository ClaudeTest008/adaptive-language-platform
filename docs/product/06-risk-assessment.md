# Risk Assessment

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|------------|
| R1 | Firestore schema wrong for future multi-category expansion; costly migration | Medium | High | Category/country/exam modeled as first-class entities from V1; migration strategy documented in `docs/database/` |
| R2 | Firestore read costs grow with question volume | Medium | Medium | Client-side caching, offline persistence, paginated question fetch; per-session question batches |
| R3 | Weak security rules expose user data or allow content tampering | Low | High | Rules written alongside schema, tested with Firestore emulator in CI; admin writes verified via custom claims |
| R4 | Question content quality poor (wrong answers, weak explanations) | Medium | High | Admin analytics flag anomalous per-question accuracy; explanation mandatory at question creation |
| R5 | Scope creep beyond V1 (AI features, more categories) | High | Medium | ROADMAP epics fixed; out-of-scope list in business requirements; ADR required to change scope |
| R6 | Flutter web performance inadequate for admin panel | Low | Medium | Admin panel is simple CRUD; if inadequate, panel can move to lightweight web stack without touching mobile app (kept in separate Flutter target) |
| R7 | Single-developer bus factor / AI-session context loss | High | Medium | Repository documentation discipline: AI_CONTEXT, PROJECT_STATUS, TASKS updated every session; ADRs record rationale |
| R8 | App store rejection (account deletion, privacy) | Low | High | Account deletion in Settings (FR-7.3); privacy-conscious analytics from day one |
| R9 | Firebase vendor lock-in | Medium | Low–Medium | Clean Architecture isolates Firebase behind repository interfaces in the infrastructure layer; domain layer Firebase-free |
