# ADR-0015: Language Domain Model and Knowledge Graph Extension

**Status:** Accepted
**Date:** 2026-07-16

## Context

Phase 1 needs the language knowledge hierarchy (Language → Level → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation), typed language relationships (interference, false friends, cultural context), per-skill mastery, and CEFR curricula — without touching the Adaptive Learning Core (ADR-0014). The inherited `CurriculumNode` (ADR-0012) has 8 exam-shaped tiers; the language hierarchy has 11. The core engine's contract is concept-id **strings** plus the `KnowledgeGraph`/`ConceptNode` structure (ADR-0008); it never sees domain types.

## Decision

1. New layer `lib/language/` (pure Dart, imports nothing from Flutter/Firebase; only `adaptive/graph.dart` for the projection). This is the "Adaptive Language Platform" tier of the ADR-0014 layering.
2. **`LanguageNode` is a parallel naming discipline, not a `CurriculumNode` reuse.** Same design (hierarchical `conceptId`, lineage ids, strictly-deepening tiers with skips allowed), language-specific tier set. Reusing `CurriculumLevel` would force 11 tiers into 8 exam names; the engine only consumes the id strings, so the discipline — not the type — is what ADR-0012 standardizes. Typed subclasses carry content: `GrammarConceptNode` (pattern, explanation, transferTraps), `VocabularyConceptNode` (lemma, translations, frequencyRank), `PhraseNode`, `ExampleSentenceNode`, `ExerciseNode` (10 exercise types), `ConversationNode` (scenario).
3. **Typed relations live in `LanguageKnowledgeGraph`; the core graph stays unchanged.** Relation types: `requires`, `buildsOn`, `interferesWith`, `culturalContext`, `falseFriend`, `relatedTo`. `toCoreGraph()` projects them down (requires → prerequisites, buildsOn → followUps+related, rest → related both directions, parent lineage → prerequisite), so lapse propagation, scheduling and selection work as-is. Relation endpoints may reference concepts outside the hierarchy (native-language patterns like `en:be-adjective`) — they become plain nodes in the projection and interference sources for the misconception engine.
4. **Language signals sit beside the LearnerModel, not inside it.** `LanguageConceptSignals` (recall difficulty/speed, pronunciation confidence, listening recognition, grammar-transfer errors, usage frequency, native interference) is keyed by the same concept ids. Per-skill mastery (`skillMastery`, `weakestSkills`) aggregates the core mastery map read-only via each concept's skill lineage. Wiring into answer events is Phase 2.
5. **Curricula are data**: JSON per (target language, native language) pair validated by `assets/curriculum/curriculum.schema.json`, parsed by `parseCurriculum` (parents-first node list, fail-fast on unknown parents/tier violations). Seeds: `es-for-en.json` (incl. tener-states misconception family, ser/estar, embarazada false friend, cultural context), `en-for-es.json` (third-person -s, pro-drop interference, actually/actualmente).

## Consequences

- Core untouched: zero diffs under `lib/adaptive/`; all 89 inherited tests unchanged and green.
- AI tutor (Phase 3) gets structured context for free: transfer traps, relation notes, scenarios are authored data.
- Misconception engine (Phase 2) consumes `interference()` + `transferTraps`; daily lessons (Phase 4) consume `weakestSkills`.
- Duplication of the CurriculumNode pattern (~40 lines) accepted in exchange for exact tiers and zero risk to exam-inherited code paths.
- Curriculum JSON is authoring format AND seed data; Firestore persistence shape drafted in `docs/database/05-language-schema.md`, implemented Phase 8.
- No language repository interfaces in Phase 1 by design: the inherited interfaces (`lib/domain/repositories.dart`, `lib/adaptive/repository.dart`) are the seams language behavior enters through (ADR-0014 §2). Language-specific persistence contracts (signals, misconceptions) arrive with Phase 2 signal wiring — with their first producer/consumer, not before.
