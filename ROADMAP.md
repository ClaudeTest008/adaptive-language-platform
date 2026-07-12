# Roadmap

Master plan for the Adaptive Language Platform. Phases are sequential; each ends with working, tested, documented software. Inherited exam-platform epics (0–18) live in the git history and the original repository; this roadmap starts fresh for the language product.

## Phase 0 — Fork Foundation ✅ (2026-07-12)

- Repository `adaptive-language-platform` created as history-preserving fork of `adaptive-exam-platform` (ADR-0014).
- Product identity: README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG rewritten for the language platform.
- ADR structure continued (0001–0013 inherited; 0014 records the fork).

## Phase 1 — Language Domain Model

- Language knowledge hierarchy: Language → Level → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation.
- Domain entities: Language, Learner, Skill (10 skills, independent mastery), GrammarConcept, VocabularyConcept, Phrase, ExampleSentence.
- Knowledge graph extension: language relationship graphs (verb → tense → conjugation family → examples; semantic vocabulary networks) via the inherited curriculum-hierarchy concept ids (ADR-0012).
- Curriculum structure per language/level (CEFR-aligned levels).
- Firestore schema drafts: languages, learners, skills, vocabulary, grammar concepts.
- Tests: knowledge-graph construction, hierarchy → concept-id mapping.

## Phase 2 — Vocabulary & Grammar Adaptive Tracking

- Extend the adaptive engine (never rewrite) with language signals: recall difficulty, vocabulary strength, grammar confidence, recall speed, usage/vocabulary frequency, retention decay.
- Per-skill mastery aggregation (e.g. Spanish: Vocabulary 85%, Grammar 62%, Listening 44%).
- Misconception engine: track misconceptions separately from mistakes; detect native-language transfer (e.g. "Yo soy cansado" → `tener` pattern family); link misconceptions to related concepts.
- Exercise-type architecture: multiple choice, fill-in-blanks, translation, sentence building, reading comprehension (text-first types).
- Schema: mistakes, misconceptions, learning goals.
- Tests: vocabulary mastery, grammar mastery, misconception detection, adaptive recommendations.

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
