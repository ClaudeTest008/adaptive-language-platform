# Adaptive Language Platform

An AI-powered adaptive language learning system. Cross-platform app (Flutter) backed by a cloud backend, built on the proven Adaptive Learning Core forked from the Adaptive Exam Platform. Not a flashcard app — a personalized AI language teacher that understands the learner through a knowledge graph, Learning DNA, spaced repetition, and concept mastery.

## What Makes It Different

- **Adaptive learning engine** — tracks mastery of language concepts (grammar, vocabulary, skills), not individual exercises.
- **AI tutor** — teaches from learner history, weak concepts, misconceptions, and goals; six modes (Teacher, Conversation, Coach, Socratic, Grammar, Immersion).
- **Daily personalized lessons** — generated from mastery, review schedule, goals, and available time.
- **Misconception engine** — detects native-language transfer errors (e.g. "Yo soy cansado") and teaches the underlying pattern.
- **Content intelligence** — ingests textbooks, articles, podcasts, transcripts into structured language knowledge.

## Project Documentation

| File | Purpose |
|------|---------|
| [AI_CONTEXT.md](AI_CONTEXT.md) | Persistent context for AI development sessions |
| [ROADMAP.md](ROADMAP.md) | Master roadmap and milestones |
| [PROJECT_STATUS.md](PROJECT_STATUS.md) | Current phase and progress |
| [TASKS.md](TASKS.md) | Active and upcoming tasks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | High-level architecture |
| [CHANGELOG.md](CHANGELOG.md) | Notable changes per version |
| [docs/](docs/) | Detailed documentation by domain |

## Repository Layout

```
app/flutter/        Flutter client application
backend/            Backend services (Firestore rules, indexes)
cloud_functions/    Serverless functions
scripts/            Development and operations scripts
assets/             Shared static assets
tests/              Cross-cutting test suites
docs/               Domain documentation (product, architecture, database, ai,
                    learning-engine, security, deployment, decisions)
```

## Lineage

Forked 2026-07-12 from [adaptive-exam-platform](https://github.com/ClaudeTest008/adaptive-exam-platform) with full history (ADR-0014). The Adaptive Learning Core (adaptive engine, knowledge graph, AI orchestration, Content Studio, multi-tenancy) is inherited and reused; exam-specific concepts are being replaced by the language learning domain. The two repositories are independent — this fork never pushes back to the original.

## Status

Phase 0 — Fork foundation and product identity. See [PROJECT_STATUS.md](PROJECT_STATUS.md).
