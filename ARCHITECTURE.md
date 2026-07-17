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

Navigation is language-first (ADR-0019): the Language Lab is the home route; target language is a selector over the `availableLanguages` curriculum registry (adding a language = one curriculum JSON + one registry row). Exam-era screens are retired from navigation (deleted with the package rename). Visual identity: teal immersion Material 3 theme, gradient heroes, tutor as the primary action.

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
- `lesson.dart` — `buildDailyLesson` weighted, time-budgeted daily plan (ADR-0022; see Daily Lesson Engine below).
- `content_merge.dart` (ADR-0026) — `mergeApprovedContent` folds approved, unmapped content candidates into a copy of the curriculum as new vocab/phrase nodes under a synthesized `<lang>:<level>:vocabulary:ingested` domain (base never mutated; they generate exercises and project onto the core like any authored node); `storyFromApproved` synthesizes a story from approved sentences.
- `curriculum.dart` — CEFR curriculum loader; curricula are JSON data per (target, native) language pair (`assets/curriculum/`, schema + Spanish/English seeds).

Runtime wiring (`lib/presentation/language_providers.dart`): `LanguageLearnerController` runs every exercise answer through the UNCHANGED core `LearnerEngine` (constructed with `toCoreGraph()`), the misconception detector, and the signal store. Showcase screens: `/language` (per-skill mastery, Teacher Notes, lesson preview) and `/language/concept/:id` (signals, graph relations, live simulate).

Mastery is tracked per concept and per skill (Vocabulary, Grammar, Reading, Writing, Listening, Speaking, Pronunciation, Conversation, Culture, Comprehension — each independent). Schema drafts: `docs/database/05-language-schema.md`.

## Adaptive Learning Core (ADR-0008, inherited)

Pure-Dart module `lib/adaptive/` — no Flutter, no Firebase. Learner model (per-concept mastery, spaced-repetition schedule), knowledge graph, confidence model, adaptive selector, readiness, study plans, Learning DNA. Replaceable seams: `ReviewScheduler`, `QuestionSelector`, `LearnerModelRepository`.

Language extension (Phase 2, additive only): recall difficulty, pronunciation confidence, grammar-transfer errors, vocabulary/usage frequency, conversation ability, retention decay. Misconceptions tracked separately from mistakes.

## Content Ingestion (ADR-0025)

`ingestLanguageText` (`lib/language/ingestion.dart`, pure Dart) turns pasted target-language text into `ContentCandidate`s across five kinds (vocabulary, phrases, example sentences, idioms, cultural notes) with an estimated CEFR difficulty and topics, mapping each to a curriculum concept id where the word/phrase is recognized in the graph. A `ContentReviewLog` (+ repository seam) holds the approve/reject queue — nothing enters the curriculum unreviewed, mirroring ADR-0011's QuestionCandidate discipline. The admin-only Content Studio (`/content`, gated by `authState.isAdmin`) drives paste → extract → review. On approve, the candidate is appended to `approvedContentProvider` (durable, resets on language switch); `curriculumProvider` and `storiesProvider` watch it and fold approvals into the live graph/stories via `content_merge.dart` (ADR-0026), so ingested material surfaces in practice, stories and the plan immediately — the review queue stays the only gate. The store swaps to Firestore behind the same providers (Phase 8); an AI extractor can later feed the same queue over the `AiChatModel` seam.

## Speech & Pronunciation (ADR-0020/0024)

Speaking drills are scored by `scorePronunciationDetailed` (`lib/language/speaking.dart`): each target word aligns to its closest recognized word and scores by normalized Levenshtein over phonetically-folded forms (silent h, b/v, y/ll, qu/k, z/c→s, doubled letters, accents), yielding partial credit + per-word feedback (`PronWord`). Listening recognition is an exercise type (`ExerciseType.listening`, hidden `audio` spoken by the seam, pick-the-word) feeding a `listeningRecognition` signal. `buildDailyLesson` reads mean `pronunciationConfidence`/`conversationAbility` and weights the speaking/conversation blocks when they're low. TTS (`PlatformSpeechService`) chunks on clauses with punctuation-sized breaths and per-language / per-clause prosody. All over the unchanged `SpeechService` seam; core untouched.

## Conversation Engine (ADR-0023)

Conversation and Immersion modes run scenario-driven multi-turn dialogue. `TutorContext` carries a scenario (a `ConversationNode`) and `targetVocab` — target-language phrases drawn from the learner's weak concepts; `pickScenarioConceptId` (`lib/language/conversation.dart`) weights the scenario toward weak areas. The tutor prompt instructs (and `DemoTutorModel` composes) replies that react to the learner's last message, recast errors in-reply, weave a target phrase, progress the scene, and end with a follow-up. Each learner turn is scored (`conversationTurnQuality`) and moves the `conversationAbility` signal on the scenario concept (signal-only; the core is untouched). Provider-blind over the same `AiChatModel` seam.

## AI Tutor (ADR-0018, `lib/language/tutor.dart`)

Provider-blind over the inherited `AiChatModel` seam (ADR-0010; `lib/ai/` untouched — the tutor is language-platform orchestration, not a core capability). Per session, `buildTutorContext` assembles an immutable `TutorContext` snapshot: skill mastery, weakest concepts, most-frequent misconceptions, per-concept signals, goals, live Learning DNA traits (recomputed by the core engine after every answer), and a knowledge-graph slice for the focus concept (typed relations + pattern family). Default focus = top misconception ("repair first"). Six mode contracts (Teacher, Conversation, Coach, Socratic, Grammar, Immersion): persona + per-mode `Session flow` dialogue plan + `MODE:` tag + serialized `[LEARNER CONTEXT]` + output rules. Every reply passes `validateTutorReply`: structure, focus-concept grounding, and Immersion language purity (native-stopword gate); rejected output never reaches the learner. Vendor swap point: `tutorModelProvider` (currently `DemoTutorModel` — six deterministic mode-true strategies composed from the same prompts, multi-turn aware). UI: `/language/tutor` mode selector + chat session (typing indicator, avatar bubbles). History persistence is remaining Phase 3 work.

## Daily Lesson Engine (ADR-0022, `lib/language/lesson.dart`)

`buildDailyLesson` (pure Dart) assembles today's plan: candidate blocks in priority order — misconception repair (first), spaced-repetition due concepts, weakest skills, low pronunciation-confidence concepts, a concept-overlapping story, a conversation tail — then a weighted allocator budgets the available minutes (total == budget, each block ≥5 min). Learning DNA traits shape the weights and the block count; recent accuracy and available time are inputs. Each block carries a plain-language `reason` and a `LessonActivity` (practice / speaking / story / tutor) the dashboard launches on tap. The engine imports no core code: the provider computes due concepts from core `ConceptStats` and passes primitives. The available-minutes budget comes from the learner's goal (`learnerGoalsProvider` → `availableMinutesProvider`, ADR-0026), which also caps the story queue at the target CEFR level and sets the tutor's goal string; the `/goals` screen edits both (in-memory in demo mode).

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
