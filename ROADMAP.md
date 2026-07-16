# Roadmap

Master plan for the Adaptive Language Platform. Phases are sequential; each ends with working, tested, documented software. Inherited exam-platform epics (0–18) live in the git history and the original repository; this roadmap starts fresh for the language product.

## Phase 0 — Fork Foundation ✅ (2026-07-12)

- Repository `adaptive-language-platform` created as history-preserving fork of `adaptive-exam-platform` (ADR-0014).
- Product identity: README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG rewritten for the language platform.
- ADR structure continued (0001–0013 inherited; 0014 records the fork).

## Phase 1 — Language Domain Model ✅ (2026-07-16)

- ✅ Language knowledge hierarchy (`lib/language/entities.dart`): 11-tier `LanguageNode` discipline, typed grammar/vocabulary/phrase/example/exercise/conversation nodes, CEFR levels, 10 skills. (ADR-0015)
- ✅ Knowledge graph extension (`lib/language/relationships.dart`): typed relations (requires, buildsOn, interferesWith, culturalContext, falseFriend, relatedTo) projected onto the unchanged core graph.
- ✅ Language signals + per-skill mastery (`lib/language/signals.dart`): recall difficulty/speed, pronunciation confidence, listening recognition, grammar-transfer errors, usage frequency, native interference; `skillMastery`/`weakestSkills`.
- ✅ CEFR curriculum as data: JSON schema + loader + Spanish-for-English and English-for-Spanish seeds (`assets/curriculum/`).
- ✅ Firestore schema drafts: `docs/database/05-language-schema.md`.
- ✅ Tests: hierarchy ids/lineage, tier validation, relation queries, core projection, skill aggregation, seed parsing (10 new; 99 total green).

## Phase 2 — Vocabulary & Grammar Adaptive Tracking (core complete 2026-07-16)

- ✅ Language signals from answer events (ADR-0016): EWMA recall difficulty/speed, usage frequency, grammar-transfer errors, native interference — beside the unchanged core model (`signals.dart`, `LanguageSignalsStore` + repository seam).
- ✅ Per-skill mastery aggregation surfaced in UI (Language Lab dashboard: per-skill animated bars).
- ✅ Misconception engine (`misconceptions.dart`): graph-authorized detection (interference relations + transfer traps), log separate from mistakes, occurrences merge, related-concept pattern families; Teacher Notes UI.
- ✅ Core engine reused unchanged for language mastery: `LearnerEngine(graph: toCoreGraph())`, lineage concept ids.
- ✅ Showcase UI: `/language` dashboard + `/language/concept/:id` detail with live simulate (ADR-0016).
- ✅ Daily lesson preview (repair-first stopgap; full engine in Phase 4).
- ✅ Tests: detection, log merge, signal updates, end-to-end through core engine, widget tests for both screens (110 total green).
- ⏳ Remaining: text-first exercise flows (multiple choice, fill-in-blanks, translation, sentence building, reading comprehension) wired to `recordAnswer`; learning-goals schema usage.

## Phase 3 — AI Tutor Foundation

- Tutor built on inherited AI orchestration (`lib/ai/`, ADR-0010); provider-independent, output validated.
- Tutor context assembly: learner history, knowledge graph, Learning DNA, previous mistakes, weak concepts, goals, learning style.
- Six modes as orchestrator capabilities: Teacher (explain/lesson/correct), Conversation (natural dialogue, vocabulary adaptation), Coach (goals, motivation, planning), Socratic (guided questions), Grammar (pattern explanation), Immersion (target language only).
- Schema: AI tutor history.
- Tests: tutor orchestration, mode contracts, context assembly.

## Phase 4 — Daily Personalized Lesson Engine

- Daily plan generated from mastery, weak areas, review schedule, goals, available time, past performance.
- Time-budgeted plans across skills (e.g. 10 min vocabulary review, 15 min grammar repair, 10 min conversation, 5 min pronunciation).
- Schema: lesson plans.
- Tests: daily lesson generation (determinism, time budgets, weak-area priority).

## Phase 5 — Conversation Engine

- Conversation simulation exercises; dialogue state, vocabulary adaptation to learner level.
- Conversation ability signal into the adaptive engine.
- Schema: conversations.
- Tests: conversation flow contracts.

## Phase 6 — Speech & Pronunciation

- Speaking practice and pronunciation scoring exercise types.
- Speech-model provider seam (same vendor-independence rules as chat models).
- Pronunciation confidence + listening recognition signals.
- Schema: pronunciation attempts.

## Phase 7 — Content Ingestion for Language Resources

- Adapt Content Studio + ingestion pipeline (ADR-0011) for language resources: textbooks, novels, articles, podcasts, videos, transcripts, grammar books, course material.
- Extraction: vocabulary, grammar patterns, example sentences, expressions, idioms, difficulty level, topics, cultural references.
- Review queue unchanged: all extracted content is a candidate until human approval.
- Schema: content sources.
- Tests: content extraction contracts.

## Phase 8 — Production Deployment

- Firebase production integration (runbooks inherited in `docs/deployment/`), Firestore repository swap, RC checklists, monitoring.

## Principles

- The Adaptive Learning Core is extended, never rewritten.
- Language features stay separated from the core.
- No vendor lock-in; AI output always validated.
- Repository is the single source of truth; every session updates status docs and commits.
