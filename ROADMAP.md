# Master Roadmap v2.0

Work executes in this exact order. One epic at a time. Do not repeat completed epics.

| Epic | Title | Status |
|------|-------|--------|
| 0 | Repository Foundation | ✅ Complete |
| 1 | Product Definition | ✅ Complete |
| 2 | System Architecture | 🔄 Next |
| 3 | Database Design | Pending |
| 4 | Backend Foundation | Pending |
| 5 | Flutter Foundation | Pending |
| 6 | Question Engine | Pending |
| 7 | Practice Mode | Pending |
| 8 | Mock Exams | Pending |
| 9 | Progress Dashboard | Pending |
| 10 | Admin Panel | Pending |
| 11 | Testing | Pending |
| 12 | Deployment | Pending |

## Epic 0 — Repository Foundation ✅

Repository created with full directory structure and foundation documents. See `README.md` for layout.

## Epic 1 — Product Definition ✅

Delivered in `docs/product/`:
- Business requirements (`01-business-requirements.md`)
- Product requirements: functional + non-functional (`02-product-requirements.md`)
- Personas and user journeys (`03-personas-and-user-journeys.md`)
- Learning philosophy (`04-learning-philosophy.md`)
- Success metrics (`05-success-metrics.md`)
- Risk assessment (`06-risk-assessment.md`)

## Epic 2 — System Architecture

Application architecture, Flutter architecture, Firebase architecture, security architecture, offline strategy, error handling, logging, analytics, ADRs. Deliverables in `docs/architecture/`, `docs/security/`, `docs/decisions/`, and `ARCHITECTURE.md`.

## Epic 3 — Database Design

Firestore schema, relationships, indexes, security rules, validation, migration strategy. Deliverables in `docs/database/`.

## Epic 4 — Backend Foundation

Firebase project setup, Authentication, Cloud Functions scaffold, authorization (custom claims), Firestore provisioning, Storage.

## Epic 5 — Flutter Foundation

App scaffold, navigation/routing, dependency injection, theme (Material 3, light/dark), localization scaffolding, shared components.

## Epic 6 — Question Engine

Question repository, answer validation, bookmarks, review-incorrect, search.

## Epic 7 — Practice Mode

Question flow, immediate feedback, explanations, statistics recording.

## Epic 8 — Mock Exams

Randomization, timer, scoring, pass/fail, results storage.

## Epic 9 — Progress Dashboard

Statistics, weak topics, study history, achievements (basic).

## Epic 10 — Admin Panel

Exam management, question management, image upload, user management, analytics.

## Epic 11 — Testing

Unit tests, widget tests, integration tests, performance checks, testing documentation.

## Epic 12 — Deployment

CI/CD (GitHub Actions: format, analyze, test, build), production builds, Firebase deployment, documentation, release candidate.

## Version 2+ (not V1 — architecture-ready only)

Additional exam categories, adaptive learning, AI tutor/explanations/study plans, knowledge graph, spaced repetition, institutional/corporate features, white-label deployments, monetization.
