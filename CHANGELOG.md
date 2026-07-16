# Changelog

All notable changes to the Adaptive Language Platform are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Changes before 2026-07-12 belong to the exam-platform lineage; see git history and the original `adaptive-exam-platform` repository.

## [Unreleased]

### Added

- 2026-07-16: Phase 2 core — misconception engine + language signal tracking + Language Lab UI (ADR-0016): graph-authorized misconception detection (interferesWith/falseFriend relations + transfer traps) recorded separately from mistakes with explanations and pattern families; EWMA signal updates from answer events (recall difficulty/speed, usage frequency, grammar-transfer errors, native interference) beside the unchanged core LearnerModel; persistence seams with in-memory demo implementations; core LearnerEngine reused unchanged via the language graph projection; `/language` dashboard (animated per-skill mastery, Teacher Notes, repair-first lesson preview) and `/language/concept/:id` detail (signals, relations, live simulate); app title → Adaptive Language Platform; 11 new tests (110 green).

- 2026-07-16: Phase 1 — language domain model (ADR-0015): `lib/language/` pure-Dart layer with 11-tier knowledge hierarchy (typed grammar/vocabulary/phrase/example/exercise/conversation nodes, CEFR levels, 10 skills), `LanguageKnowledgeGraph` with typed relations (requires/buildsOn/interferesWith/culturalContext/falseFriend/relatedTo) projected onto the unchanged core graph, language memory signals + per-skill mastery aggregation, CEFR curriculum JSON schema/loader with Spanish-for-English and English-for-Spanish seeds, Firestore schema drafts (`docs/database/05-language-schema.md`); 10 new tests, 99 total green, core untouched.

- 2026-07-12: Phase 0 — repository forked from `adaptive-exam-platform` with full history (ADR-0014); product identity rewritten for the Adaptive Language Platform (README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG); roadmap defined (Phases 0–8: language domain model → adaptive tracking → AI tutor → daily lessons → conversation → speech → content ingestion → production).
