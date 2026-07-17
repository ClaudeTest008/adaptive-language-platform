# ADR-0024: Pronunciation Scoring, Listening Recognition, Signal-Weighted Lessons

**Status:** Accepted
**Date:** 2026-07-17

## Context

Pronunciation was scored by token overlap — a word was either present or absent, no partial credit, no per-word feedback. There was no listening exercise, and the two production signals (`pronunciationConfidence`, `conversationAbility`) fed nothing back into the daily plan. Phase 6 deepens speech without touching the core or the `SpeechService` seam.

## Decision

1. **Phoneme-aware pronunciation scoring** (`lib/language/speaking.dart`): `scorePronunciationDetailed` aligns each target word to its closest word in the recognizer transcript and scores by normalized Levenshtein over **phonetically-folded** forms — silent h, b/v, y/ll, qu/k, z/c→s, doubled letters collapse, accents fold. A near miss earns partial credit instead of zero; the result carries **per-word feedback** (`PronWord`: target, heard, similarity, ok). `scorePronunciation` stays as the 0..1 façade for the signal update. The speaking screen shows per-word ✓/✗ chips.
2. **Listening recognition exercise** (`ExerciseType.listening`): generated from vocabulary — the lemma is spoken (a new `ExerciseItem.audio`, never shown) and the learner picks which word they heard. Auto-plays on appear with a "Play again" button. A correct/incorrect answer moves a new `listeningRecognition` EWMA (`afterListening`), recorded via `recordAnswer(listening: true)`.
3. **Signals feed the lesson engine**: `buildDailyLesson` computes mean `pronunciationConfidence` and `conversationAbility` over tracked concepts and **weights the speaking and conversation blocks up when those signals are low** (and softens the reasons accordingly). Low spoken confidence → more pronunciation minutes; thin conversation ability → more conversation minutes.
4. **Voice quality**: `PlatformSpeechService` now uses per-language base prosody, splits on clauses (commas/colons too, not just sentences) with breaths sized to the punctuation, and shapes pitch/rate by clause type (questions rise and slow, exclamations lift). Sits on top of the existing enhanced-voice selection.
5. **UI polish**: premium theme pass — pill NavigationBar indicator with select-only labels, flat scrolled app bars, rounded filled buttons and filled input fields. No floating elements remain in the live UI (the FAB went in Phase 4; the "emoji" icons flagged were trophy glyphs in retired exam screens); the keyboard shows only on field focus.

## Consequences

- Pronunciation feedback is actionable (which word slipped) and fair (near misses count); listening is a first-class exercise with its own signal.
- The daily plan now self-corrects toward speaking/conversation when those are the weak modalities — closing the loop the earlier signals only opened.
- Scoring is still an approximation over the device recognizer's transcript; true phoneme/prosody quality needs a cloud speech model (future work). The seam is unchanged, so that swap stays local to infrastructure.
