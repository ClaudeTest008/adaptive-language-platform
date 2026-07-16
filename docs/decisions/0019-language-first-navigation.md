# ADR-0019: Language-First Navigation and Product Rebrand

**Status:** Accepted
**Date:** 2026-07-16

## Context

Through Phase 3 the app still presented as the exam product: exam dashboard at `/`, practice/mock-exam/bookmarks/admin routes, "Exam Prep" branding on login/settings/web manifest, blue exam theme. The Language Lab lived behind a dashboard card. The product IS the language platform now.

## Decision

1. **The Language Lab is the app.** `/` renders the Language Lab; `/language` redirects for legacy deep links. Exam-era routes (`/practice` exam flows, `/exam`, `/bookmarks`, `/search`, `/admin`) are removed from the router. Their screen files remain in-tree, unrouted, until the package-rename sweep deletes them (tracked in TASKS) — retirement is a navigation decision, not a code deletion.
2. **Multi-language via selector, not rebuild.** `availableLanguages` registry (code, name, flag, curriculum asset) + `selectedLanguageProvider`; `curriculumProvider` and every language controller watch it. A new language = one curriculum JSON + one registry row. Demo seeds are per-language scripts.
3. **Fresh learner per language in demo mode.** On controller (re)build the misconception/signal stores are reset before seeding — the core model is never persisted in demo mode, so stores must match it or a switch would leak the previous language's misconceptions and inflate occurrence counts on round trips (found by adversarial review, regression-tested). Repository loading returns with LearnerModel persistence (Phase 8).
4. **Immersion visual identity:** teal seed (#00897B) Material 3 scheme, gradient hero cards, frosted pills, rounded 16 cards, tutor as floating action + hero card. Web manifest/index rebranded; login/settings copy rewritten.

## Consequences

- No exam-flavored surface is reachable: router defines login, Language Lab, tutor, practice, concept, settings only.
- Dead exam screens remain in-tree (compile but unreachable); deleted with the `adaptive_exam_platform` package rename.
- Inherited Content Studio is unreachable from the UI until it is re-skinned for language content (Phase 7 ingestion work).
- Tutor goals derive from the selected curriculum ("Reach A2 {language}") until real learner goals land (Phase 4 schema).
