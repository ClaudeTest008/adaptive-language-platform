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

## Language Domain Model (ADR-0015, `lib/language/`)

Language → Level (CEFR A1–C2 + custom) → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation

Pure-Dart layer `lib/language/` — the "Adaptive Language Platform" tier of the layering:

- `entities.dart` — `LanguageNode` hierarchy (parallel naming discipline to ADR-0012's CurriculumNode: hierarchical concept ids like `es:a1:grammar:verbs:present-tense:ar-verbs`, lineage ids, tier-order validation). Typed nodes: `GrammarConceptNode` (pattern + transfer traps), `VocabularyConceptNode` (lemma, translations, frequency rank), `PhraseNode`, `ExampleSentenceNode`, `ExerciseNode` (10 exercise types), `ConversationNode` (scenario).
- `relationships.dart` — `LanguageKnowledgeGraph` with typed relations (`requires`, `buildsOn`, `interferesWith`, `culturalContext`, `falseFriend`, `relatedTo`); `toCoreGraph()` projects onto the unchanged core `KnowledgeGraph` (ADR-0008), so the engine consumes language structure without knowing languages exist. Interference endpoints may be native-language patterns outside the hierarchy (`en:be-adjective`) — misconception engine input.
- `signals.dart` — `LanguageConceptSignals` (recall difficulty/speed, pronunciation confidence, listening recognition, conversation ability, grammar-transfer errors, usage frequency, native interference) beside — not inside — the core LearnerModel; `afterAnswer` EWMA updates from answer events (ADR-0016); `LanguageSignalsStore` + repository seam; `skillMastery`/`weakestSkills` aggregate per-skill mastery (10 independent skills) read-only from the core mastery map.
- `misconceptions.dart` (ADR-0016) — misconception engine: `MisconceptionDetector` fires only on wrong answers with graph-authorized interference (`interferesWith`/`falseFriend` relations, grammar transfer traps); `MisconceptionLog` records misconceptions SEPARATELY from mistakes with native language, source, pattern, explanation, related pattern family; repository seam with in-memory demo implementation.
- `lesson.dart` — repair-first daily lesson preview (deterministic, time-budgeted); stopgap until the Phase 4 lesson engine.
- `curriculum.dart` — CEFR curriculum loader; curricula are JSON data per (target, native) language pair (`assets/curriculum/`, schema + Spanish/English seeds).

Runtime wiring (`lib/presentation/language_providers.dart`): `LanguageLearnerController` runs every exercise answer through the UNCHANGED core `LearnerEngine` (constructed with `toCoreGraph()`), the misconception detector, and the signal store. Showcase screens: `/language` (per-skill mastery, Teacher Notes, lesson preview) and `/language/concept/:id` (signals, graph relations, live simulate).

Mastery is tracked per concept and per skill (Vocabulary, Grammar, Reading, Writing, Listening, Speaking, Pronunciation, Conversation, Culture, Comprehension — each independent). Schema drafts: `docs/database/05-language-schema.md`.

## Adaptive Learning Core (ADR-0008, inherited)

Pure-Dart module `lib/adaptive/` — no Flutter, no Firebase. Learner model (per-concept mastery, spaced-repetition schedule), knowledge graph, confidence model, adaptive selector, readiness, study plans, Learning DNA. Replaceable seams: `ReviewScheduler`, `QuestionSelector`, `LearnerModelRepository`.

Language extension (Phase 2, additive only): recall difficulty, pronunciation confidence, grammar-transfer errors, vocabulary/usage frequency, conversation ability, retention decay. Misconceptions tracked separately from mistakes.

## AI Tutor (Phase 3)

Built on the inherited AI orchestration (`lib/ai/`, ADR-0010): `AiChatModel` = single vendor seam (OpenAI/Anthropic/Gemini/local/speech/translation adapters later, no lock-in); `AiOrchestrator` capabilities are vendor-blind; all AI output passes validation before reaching learners. Tutor modes as orchestrator capabilities: Teacher, Conversation, Coach, Socratic, Grammar, Immersion. Tutor context = learner history + knowledge graph + Learning DNA + mistakes + weak concepts + goals + learning style.

## Daily Lesson Engine (Phase 4)

Generates today's lesson from mastery, weak areas, review schedule, goals, available time, and past performance — a time-budgeted plan across skills (e.g. 10 min vocabulary review, 15 min grammar repair, 10 min conversation, 5 min pronunciation). Builds on inherited study-plan generation.

## Content Intelligence (ADR-0011, inherited)

All ingestion produces candidates in a human review queue — never published content directly. Adapted for language resources (Phase 7): textbooks, novels, articles, podcasts, videos, transcripts, grammar books. Extraction targets: vocabulary, grammar patterns, example sentences, expressions, idioms, difficulty level, topics, cultural references.

## Exercise Types (ADR-0017)

Text-first types live: multiple choice, fill-in-blank, translation, sentence building, reading comprehension — **derived from curriculum data** (`lib/language/exercises.dart`, deterministic seeded generation, repair concepts first, diacritic-preserving answer checks), served by `/language/practice`. Every submission is a real answer event: core engine mastery, lineage-walking misconception detection (child-exercise errors implicate ancestor grammar concepts) and signal updates, with teacher notes inline. Listening, speaking, pronunciation scoring, conversation simulation, writing correction arrive with their engines (Phases 5–6).

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
| Language domain model | Parallel 11-tier naming discipline, typed relations projected onto core graph, curricula as JSON data | 0015 |
