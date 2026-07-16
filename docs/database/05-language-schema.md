# Language Platform Schema (draft)

Firestore schema drafts for the language domain (ADR-0015). Extends — never replaces — the inherited schema (01–04). Implementation lands with the Firestore swap (Phase 8); demo repositories serve these shapes until then.

Concept ids everywhere are the hierarchical language ids (`es:a1:grammar:verbs:present-tense:ar-verbs`), shared with the adaptive engine's learner model.

## Collections

### `languages/{code}`

```
{ code: "es", name: "Spanish", levels: ["a1","a2","b1","b2","c1","c2"] }
```

### `curricula/{languageCode_nativeCode}`

One document per (target, native) pair, mirroring the curriculum JSON (see `assets/curriculum/curriculum.schema.json`): `language`, `nativeLanguage`, `nodes[]` (tier, slug, name, parent, prerequisites, tier-specific fields), `relations[]` (from, to, type, note). Large curricula shard `nodes` into a `nodes/{chunkId}` subcollection later (same pattern as content packs).

### `learners/{uid}` (extends inherited `users/{uid}`)

```
{
  nativeLanguage: "en",
  targetLanguages: ["es"],
  goals: [{ language: "es", type: "cefr-level", target: "b1", deadline: <ts> }],
  availableMinutesPerDay: 25,
  learningStyle: { ... }          // Learning DNA extension, Phase 3
}
```

### `learners/{uid}/languageSignals/{conceptId-hash}`

Per-concept language signals (`LanguageConceptSignals`), beside — not inside — the inherited `learnerModel` document:

```
{
  conceptId, recallDifficulty, recallSpeedMs, pronunciationConfidence,
  listeningRecognition, grammarTransferErrors, usageFrequency,
  nativeInterference, updatedAt
}
```

### `learners/{uid}/skillMastery/{language}`

Denormalized per-skill snapshot (recomputed from learnerModel on write, read cheap):

```
{ vocabulary: 0.85, grammar: 0.62, listening: 0.44, speaking: 0.38, ... }
```

### `learners/{uid}/mistakes/{id}` and `learners/{uid}/misconceptions/{id}`

Separate collections by design (misconception ≠ mistake):

```
mistakes:       { conceptId, exerciseType, given, expected, at }
misconceptions: { conceptId, interferenceSource ("en:be-adjective"),
                  relationType ("interferesWith"|"falseFriend"),
                  occurrences, explanation, relatedConceptIds[], lastSeen }
```

### `learners/{uid}/lessonPlans/{date}` (Phase 4)

```
{ date, totalMinutes, blocks: [{ skill, conceptIds[], minutes, kind: "review"|"repair"|"new"|"conversation" }] }
```

### `learners/{uid}/conversations/{id}` (Phase 5) · `learners/{uid}/pronunciationAttempts/{id}` (Phase 6)

```
conversations:         { scenarioConceptId, mode, turns[], vocabularyUsed[], startedAt }
pronunciationAttempts: { conceptId, score, phonemeScores{}, at }
```

### `learners/{uid}/tutorHistory/{sessionId}` (Phase 3)

```
{ mode: "teacher"|"conversation"|"coach"|"socratic"|"grammar"|"immersion",
  language, conceptIds[], summary, startedAt }
```

### `contentSources/{id}` (Phase 7)

```
{ kind: "textbook"|"novel"|"article"|"podcast"|"video"|"transcript"|"grammar-book"|"course",
  title, language, level, status, extractionJobId }
```

Extraction reuses the inherited documents/extractionJobs/candidates pipeline (ADR-0011).

## Security rules

Same least-privilege strategy as `02-security-rules.md`: learner subcollections owner-only; `languages` and `curricula` read-any-signed-in, write-admin. Rules deltas land with Phase 8 alongside emulator tests.
