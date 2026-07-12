# ADR-0014: Fork Adaptive Exam Platform as Adaptive Language Platform

**Status:** Accepted
**Date:** 2026-07-12

## Context

A new product is needed: an AI-powered adaptive language learning system — a personalized AI language teacher, not a flashcard app. The exam platform already contains a proven, tested Adaptive Learning Core: pure-Dart adaptive engine (learner model, knowledge graph, spaced repetition, confidence, selector, Learning DNA), vendor-independent AI orchestration, Content Studio with review-queue ingestion, Clean Architecture with repository pattern and demo mode, multi-tenancy with CI-verified isolation. Rebuilding this from scratch would duplicate months of verified work.

## Decision

1. Fork `adaptive-exam-platform` into a new, independent repository `adaptive-language-platform`, **preserving full git history** (local clone, new remote). The original repository is never modified or pushed to from this fork.
2. Reuse the Adaptive Learning Core unchanged; **extend it, never rewrite it**. Language-specific behavior enters through additive signals and the existing seams (curriculum-hierarchy concept ids, `ReviewScheduler`, `AiOrchestrator` capabilities, repository interfaces).
3. Layering: Adaptive Learning Core → Adaptive Language Platform → Language Learning Features. Language features stay separated from the core so the core remains reusable.
4. Replace the exam knowledge model with the language hierarchy: Language → Level → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation. Mastery is tracked per concept and per skill (10 independent skills), not per exercise.
5. ADRs 0001–0013 remain binding for the inherited core. Language-platform decisions start at 0014.

## Consequences

- Full provenance: every inherited line traces to its original commit; `git log` spans both products.
- Inherited code and `docs/product|architecture|database` subtrees still speak exam vocabulary; they are remodeled phase by phase (ROADMAP Phases 1–2) instead of in one big rename — docs describe the target, code catches up.
- Core changes must stay domain-agnostic; anything language-specific that leaks into `lib/adaptive/` is a defect.
- Divergence from the exam platform is permanent; fixes are not synchronized between repositories.
