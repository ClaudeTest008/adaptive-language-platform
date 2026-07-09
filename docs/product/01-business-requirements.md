# Business Requirements

## Purpose

Build a commercial-grade, cross-platform exam preparation platform. Version 1.0 supports exactly one exam domain — the Driver's License Examination — while the architecture supports unlimited certification and licensing exam types in future versions.

## Business Goals

| ID | Goal |
|----|------|
| BG-1 | Ship a production-ready V1 for driver's license exam preparation on Android, iOS, and web |
| BG-2 | Architecture supports adding new exam categories (motorcycle, CDL, medical, IT, etc.) without redesign |
| BG-3 | Foundations in place for future intelligent learning features (adaptive learning, AI tutor, knowledge graph) |
| BG-4 | Content managed by administrators through a web admin panel — no developer involvement for content changes |
| BG-5 | Repository quality high enough for any professional engineering team to continue development |

## Business Model (Future — Not V1)

V1 ships without monetization. The data model must not block later addition of: subscriptions, one-time exam-pack purchases, institutional licensing, and white-label deployments.

## Scope Boundaries

**In scope for V1:** authentication, user profile, driver's license category, practice mode with immediate feedback and explanations, bookmarks, review of incorrect answers, mock exams with timer and pass/fail scoring, progress dashboard with weak topics, search, settings, web admin panel, testing, CI/CD.

**Explicitly out of scope for V1:** any exam category other than driver's license, AI-generated content, adaptive question selection, payments, social features, gamification beyond basic statistics, offline-first sync (offline-friendly caching only).

## Stakeholders

| Stakeholder | Interest |
|-------------|----------|
| Learners | Pass the driver's license exam through understanding, not memorization |
| Administrators | Manage exams, questions, images, and users without technical skills |
| Future institutions | White-label / corporate deployments (architecture-level consideration only) |
| Engineering | Maintainable Clean Architecture codebase with full documentation |

## Constraints

- Technology stack fixed: Flutter (Android/iOS/web) + Firebase (Auth, Firestore, Functions, Storage, Analytics, Crashlytics).
- Documentation carries equal priority to code.
- Every important technical decision requires an ADR in `docs/decisions/`.
