# AI Context

This file is the permanent memory of the project for AI development sessions. Read it at the start of every session. Keep it accurate and short.

## What This Project Is

**Adaptive Language Platform** — AI-powered adaptive language learning system:

- Flutter client app (`app/flutter/`)
- Backend services (`backend/`)
- Serverless functions (`cloud_functions/`)
- Adaptive Learning Core (inherited, `lib/adaptive/` + `lib/ai/`) — see Lineage below

Goal: a personalized AI language teacher, not a flashcard app. The adaptive engine tracks mastery of language **concepts** (grammar patterns, vocabulary, skills), not individual exercises.

## Lineage (ADR-0014)

Forked 2026-07-12 from `adaptive-exam-platform` with full git history. Everything up to commit `3b597b2` is inherited exam-platform work. The Adaptive Learning Core is reused, not rewritten:

- `lib/adaptive/` — learner model, knowledge graph, scheduler, selector, confidence, Learning DNA (pure Dart)
- `lib/ai/` — AiChatModel provider seam, AiOrchestrator
- `lib/application/` — import pipeline, quality engine, document ingestion (becomes language content intelligence)
- `lib/domain/` + `lib/infrastructure/` — Clean Architecture repository pattern, demo mode (ADR-0006)
- Content Studio, multi-tenancy, search/notification seams

Layering: **Adaptive Learning Core → Adaptive Language Platform → Language Learning Features.** Extend the core with language signals; never rewrite it. Keep language-specific features separate from the core.

## Rules for AI Sessions

1. Read `PROJECT_STATUS.md` and `TASKS.md` before starting work.
2. Complete one well-defined task at a time; do not start unrelated work.
3. Read only the documentation referenced by the current task.
4. Never recreate files that already exist; continue from the current state.
5. Record architectural decisions in `docs/decisions/` (one file per decision).
6. Update `PROJECT_STATUS.md`, `TASKS.md`, and `CHANGELOG.md` when a milestone or task completes.
7. Keep commits small and focused; report the commit hash after each commit.
8. Never push to or modify the original `adaptive-exam-platform` repository.

## Language Learning Model

Knowledge hierarchy (replaces exam category → topic → question):

Language → Level → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation

Skills with independent mastery: Vocabulary, Grammar, Reading, Writing, Listening, Speaking, Pronunciation, Conversation, Culture, Comprehension.

Language-specific memory signals (extend LearnerModel, don't replace): vocabulary strength, grammar confidence, recall speed, pronunciation confidence, listening recognition, speaking ability, common mistakes, native-language interference, retention decay.

Misconceptions tracked separately from mistakes (e.g. "Yo soy cansado" = English grammar transfer → teach `tener` pattern family).

AI tutor modes (architecture in Phase 3): Teacher, Conversation, Coach, Socratic, Grammar, Immersion. Tutor consumes learner history, knowledge graph, Learning DNA, mistakes, weak concepts, goals, learning style. Provider-independent (OpenAI/Anthropic/Gemini/local/speech/translation); all AI output passes validation.

## Current State

- Phase 0 (fork foundation): repository created from exam-platform history, docs rebranded, ADR-0014 recorded. No language features built yet.
- Inherited codebase state (as of fork): Flutter 3.44.5 (SDK at `C:\Users\Admin\flutter`), Riverpod 3 (`StateProvider` needs `flutter_riverpod/legacy.dart`; `AsyncValue.valueOrNull` is now `.value`), go_router 16. Repository interfaces in `lib/domain/repositories.dart`; demo implementations in `lib/infrastructure/`; swap point = providers in `lib/presentation/providers.dart`. 89 Flutter tests + 22 rules tests green at fork point. CI: `.github/workflows/ci.yml`.
- Inherited domain still speaks "exam/question" language — domain remodel is Phase 1.
- Next: Phase 1 — language domain model, knowledge graph extension, curriculum structure. See ROADMAP.md.

## Key Conventions

- Documentation lives in `docs/` split by domain; root-level files are indexes and state.
- Decision records: `docs/decisions/NNNN-title.md`. ADRs 0001–0013 inherited from exam platform (still binding for the core); 0014+ are language-platform decisions.
