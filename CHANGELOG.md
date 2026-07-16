# Changelog

All notable changes to the Adaptive Language Platform are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Changes before 2026-07-12 belong to the exam-platform lineage; see git history and the original `adaptive-exam-platform` repository.

## [Unreleased]

### Added

- 2026-07-16: Product rebrand — language-first navigation + immersion UI (ADR-0019): Language Lab home at `/`, exam routes retired from navigation, multi-language selector (Spanish/English registries + per-language demo seeds, fresh learner state per switch — cross-language contamination found by adversarial review and fixed with regression tests), teal immersion Material 3 theme with gradient/tutor hero cards and AI Tutor FAB, Today's-plan-first dashboard, rebranded login/settings/web manifest, curriculum-derived tutor goals; 132 tests green.

- 2026-07-16: Phase 3 foundation — AI tutor (ADR-0018): `TutorContext` assembled per session from real learner state (skill mastery, weakest concepts, misconceptions, signals, goals, Learning DNA, focus-concept graph slice); six tutor mode contracts (Teacher/Conversation/Coach/Socratic/Grammar/Immersion) with distinct personas over serialized learner context; output validation gate (structure + focus-concept grounding, rejected output never shown); provider-blind `LanguageTutor` over the `AiChatModel` seam with `DemoTutorModel` for offline live demo (misconception repair first, pattern family second); `/language/tutor` mode selector + chat session UI and dashboard CTA; 11 new tests (131 green).

- 2026-07-16: Phase 2 finish — text-first exercise flows (ADR-0017): exercises derived from curriculum data (multiple choice, fill-in-blank, translation, sentence building, reading comprehension; deterministic seeded generation; repair concepts first; diacritic-preserving answer checks); `/language/practice` session screen with animated progress, inline teacher notes from the misconception engine and score summary; misconception detection now walks the concept lineage (child-exercise errors implicate ancestor grammar concepts); `recordAnswer` returns detections and awaits init; dashboard "Practice your weak spots" CTA; three new seed example sentences; 10 new tests (120 green).

- 2026-07-16: Phase 2 core — misconception engine + language signal tracking + Language Lab UI (ADR-0016): graph-authorized misconception detection (interferesWith/falseFriend relations + transfer traps) recorded separately from mistakes with explanations and pattern families; EWMA signal updates from answer events (recall difficulty/speed, usage frequency, grammar-transfer errors, native interference) beside the unchanged core LearnerModel; persistence seams with in-memory demo implementations; core LearnerEngine reused unchanged via the language graph projection; `/language` dashboard (animated per-skill mastery, Teacher Notes, repair-first lesson preview) and `/language/concept/:id` detail (signals, relations, live simulate); app title → Adaptive Language Platform; 11 new tests (110 green).

- 2026-07-16: Phase 1 — language domain model (ADR-0015): `lib/language/` pure-Dart layer with 11-tier knowledge hierarchy (typed grammar/vocabulary/phrase/example/exercise/conversation nodes, CEFR levels, 10 skills), `LanguageKnowledgeGraph` with typed relations (requires/buildsOn/interferesWith/culturalContext/falseFriend/relatedTo) projected onto the unchanged core graph, language memory signals + per-skill mastery aggregation, CEFR curriculum JSON schema/loader with Spanish-for-English and English-for-Spanish seeds, Firestore schema drafts (`docs/database/05-language-schema.md`); 10 new tests, 99 total green, core untouched.

- 2026-07-12: Phase 0 — repository forked from `adaptive-exam-platform` with full history (ADR-0014); product identity rewritten for the Adaptive Language Platform (README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG); roadmap defined (Phases 0–8: language domain model → adaptive tracking → AI tutor → daily lessons → conversation → speech → content ingestion → production).
