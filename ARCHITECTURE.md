# Architecture

High-level overview. Details in `docs/architecture/`; security in `docs/security/`; decisions in `docs/decisions/`.

## Layering Principle

```
┌─────────────────────────────────────────────┐
│ Language Learning Features                  │
│  AI tutor modes · daily lesson engine ·     │
│  conversation practice · pronunciation ·    │
│  misconception engine · immersion           │
├─────────────────────────────────────────────┤
│ Adaptive Language Platform                  │
│  language domain model · language knowledge │
│  graph · language memory signals · language │
│  content intelligence                       │
├─────────────────────────────────────────────┤
│ Adaptive Learning Core (inherited, frozen   │
│  in spirit — extend, never rewrite)         │
│  learner model · knowledge graph · spaced   │
│  repetition · selector · confidence · DNA · │
│  AI orchestration · Content Studio          │
└─────────────────────────────────────────────┘
```

Language-specific features live above the core and feed it signals; the core stays domain-agnostic and reusable (ADR-0014).

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

## Language Knowledge Hierarchy

Language → Level → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation

Maps onto the inherited curriculum hierarchy (ADR-0012): hierarchical concept ids feed the unchanged adaptive engine. Mastery is tracked per concept and per skill (Vocabulary, Grammar, Reading, Writing, Listening, Speaking, Pronunciation, Conversation, Culture, Comprehension — each independent).

## Adaptive Learning Core (ADR-0008, inherited)

Pure-Dart module `lib/adaptive/` — no Flutter, no Firebase. Learner model (per-concept mastery, spaced-repetition schedule), knowledge graph, confidence model, adaptive selector, readiness, study plans, Learning DNA. Replaceable seams: `ReviewScheduler`, `QuestionSelector`, `LearnerModelRepository`.

Language extension (Phase 2, additive only): recall difficulty, pronunciation confidence, grammar-transfer errors, vocabulary/usage frequency, conversation ability, retention decay. Misconceptions tracked separately from mistakes.

## AI Tutor (Phase 3)

Built on the inherited AI orchestration (`lib/ai/`, ADR-0010): `AiChatModel` = single vendor seam (OpenAI/Anthropic/Gemini/local/speech/translation adapters later, no lock-in); `AiOrchestrator` capabilities are vendor-blind; all AI output passes validation before reaching learners. Tutor modes as orchestrator capabilities: Teacher, Conversation, Coach, Socratic, Grammar, Immersion. Tutor context = learner history + knowledge graph + Learning DNA + mistakes + weak concepts + goals + learning style.

## Daily Lesson Engine (Phase 4)

Generates today's lesson from mastery, weak areas, review schedule, goals, available time, and past performance — a time-budgeted plan across skills (e.g. 10 min vocabulary review, 15 min grammar repair, 10 min conversation, 5 min pronunciation). Builds on inherited study-plan generation.

## Content Intelligence (ADR-0011, inherited)

All ingestion produces candidates in a human review queue — never published content directly. Adapted for language resources (Phase 7): textbooks, novels, articles, podcasts, videos, transcripts, grammar books. Extraction targets: vocabulary, grammar patterns, example sentences, expressions, idioms, difficulty level, topics, cultural references.

## Exercise Types (Phase 2+)

Multiple choice, fill-in-blanks, translation, listening, speaking practice, pronunciation scoring, sentence building, conversation simulation, reading comprehension, writing correction. All flow answer events into the adaptive engine.

## Enterprise Platform (ADR-0012/0013, inherited)

Multi-tenancy (`/orgs/{orgId}`, membership-gated rules, CI-proven isolation), content-library inheritance, search + notification seams, background-worker contracts. Reused as-is.

## Cross-Cutting Concerns

- **Errors:** sealed `Failure` types in domain; infrastructure maps Firebase exceptions; presentation maps to user messages; uncaught → Crashlytics.
- **Logging:** thin `AppLogger` wrapper.
- **Analytics:** typed event catalog; events only, no PII.
- **Security:** Firestore rules least-privilege; admin via custom claims. See `docs/security/`.
- **Localization:** first-class — the product itself is multilingual; UI locale and target language are independent axes.

## Key Technology Decisions

| Decision | Choice | ADR |
|----------|--------|-----|
| Stack | Flutter + Firebase | 0001 |
| State management + DI + routing | Riverpod, go_router | 0002 |
| Admin panel | Same Flutter codebase, web, role-gated | 0003 |
| Offline strategy | Firestore offline persistence | 0004 |
| Adaptive engine | Pure-Dart module, replaceable seams | 0008 |
| AI orchestration | Single provider seam, vendor-blind capabilities | 0010 |
| Fork from exam platform, reuse core | History-preserving fork | 0014 |
