# Architecture

High-level overview. Details in `docs/architecture/`; security in `docs/security/`; decisions in `docs/decisions/`.

## System Overview

```
┌─────────────────────────────────────────────┐
│ Flutter App (Android / iOS / Web)           │
│  - Learner app + role-gated Admin Panel     │
│  - Clean Architecture, Riverpod, go_router  │
└──────────────────┬──────────────────────────┘
                   │ Firebase SDKs
┌──────────────────┴──────────────────────────┐
│ Firebase                                    │
│  Auth · Firestore · Cloud Functions ·       │
│  Storage · Analytics · Crashlytics          │
└─────────────────────────────────────────────┘
```

One Flutter codebase serves learners (mobile + web) and administrators (web, role-gated routes). See ADR-0003.

## Layers (Clean Architecture)

| Layer | Contents | Depends on |
|-------|----------|-----------|
| Presentation | Widgets, screens, Riverpod controllers | Application |
| Application | Use cases, application services | Domain |
| Domain | Entities, value objects, repository interfaces | nothing |
| Infrastructure | Firebase implementations of repository interfaces, DTOs/mappers | Domain (implements its interfaces) |

Rules:
- Domain layer imports no Flutter, no Firebase.
- Presentation never touches Firebase directly; always through use cases and repository interfaces.
- Dependency injection via Riverpod providers (ADR-0002); infrastructure implementations bound to domain interfaces at app startup.

## Feature-First Organization

Code organized by feature, layered inside each feature:

```
lib/
├── core/            # shared: theme, routing, errors, logging, widgets, utils
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── presentation/
│   ├── profile/
│   ├── practice/
│   ├── mock_exam/
│   ├── progress/
│   ├── search/
│   ├── settings/
│   └── admin/
└── main.dart
```

## Key Technology Decisions

| Decision | Choice | ADR |
|----------|--------|-----|
| Stack | Flutter + Firebase | 0001 |
| State management + DI | Riverpod | 0002 |
| Admin panel | Same Flutter codebase, web, role-gated | 0003 |
| Offline strategy | Firestore offline persistence | 0004 |
| Routing | go_router | 0002 |

## Cross-Cutting Concerns

- **Errors:** domain failures as sealed `Failure` types; infrastructure maps Firebase exceptions to failures; presentation maps failures to user messages. Uncaught errors go to Crashlytics.
- **Logging:** thin `AppLogger` wrapper (debug console in dev, Crashlytics breadcrumbs in prod).
- **Analytics:** typed event catalog wrapping Firebase Analytics; events only, no PII.
- **Security:** Firestore rules least-privilege; admin via custom claims. See `docs/security/`.
- **Localization:** Flutter `intl`/ARB scaffolding from day one; V1 ships English.

## Adaptive Learning Engine (ADR-0008)

Pure-Dart module `lib/adaptive/` — no Flutter, no Firebase. Learner model (per-concept mastery, spaced-repetition schedule), knowledge graph derived from content, confidence model, adaptive question selector, readiness/pass-probability, study plans, learning DNA. Replaceable seams: `ReviewScheduler` (SM-2/FSRS later), `QuestionSelector`, `LearnerModelRepository`. AI capabilities are provider-independent interfaces in `lib/domain/ai_services.dart`; no provider bound in V1.

## Future Expansion Hooks

- Exam category, country, topic are database entities (not enums) — new exam types are data, not code.
- All answer events persisted with correctness/timestamp/duration — input for future adaptive engine.
- AI features will land as new application-layer services; no layer redesign expected.
