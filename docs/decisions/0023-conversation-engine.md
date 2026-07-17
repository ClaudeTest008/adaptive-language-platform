# ADR-0023: Conversation Engine + Voice Naturalness

**Status:** Accepted
**Date:** 2026-07-17

## Context

Conversation and Immersion modes existed but were thin: two canned turns, no scenario, no memory of what the learner said, no signal produced. Phase 5 needs real multi-turn dialogue that adapts to the learner and feels like a patient teacher — while staying provider-blind over the existing `AiChatModel`/`DemoTutorModel` seam and leaving the core untouched.

## Decision

1. **Scenario-driven context.** `TutorContext` gains `scenarioConceptId`/`scenarioName`/`scenario` and `targetVocab`. `buildTutorContext(scenarioConceptId:)` pulls the `ConversationNode` scenario text and gathers target-language phrases from the learner's weak concepts (`_targetVocab`) — so a conversation practices where it hurts. `pickScenarioConceptId` (`lib/language/conversation.dart`) chooses a scenario a weak concept feeds into, else the first.
2. **The prompt carries the dialogue.** `tutorSystemPrompt` emits `Scenario:` and `Target vocabulary to weave in:` lines; the Conversation/Immersion dialogue plans now instruct: react to the learner's last message, model corrections in-reply (never lecture), weave one target phrase, move the scene forward, end with one natural follow-up. A real vendor reads this as instructions; `DemoTutorModel` reads the same fields and composes contextual, multi-turn replies (reacts to the user's last utterance, recasts errors like *soy cansado → tengo sueño*, progresses through scene beats).
3. **Conversation produces a signal.** New `conversationAbility` EWMA (`afterConversationTurn`) on `LanguageConceptSignals`; `conversationTurnQuality(reply, targetVocab)` scores a learner turn by length + target-vocab use (accent-folded). The session controller scores each learner turn and records it on the scenario concept's lineage — signal-only (a turn is production, not a graded answer). Core untouched.
4. **Wiring.** The Conversation plan block launches a Conversation session directly (mode selector for other tutor blocks). Tutor Conversation/Immersion modes pick a weak-weighted scenario on start.
5. **Voice naturalness.** `PlatformSpeechService` now speaks sentence by sentence with a short breath (~220 ms) between chunks, lifts pitch on questions for rising intonation, sets full volume, warmer defaults (rate 0.46, pitch 1.06), on top of the existing enhanced/neural voice selection. `SpeechService.speak` keeps its rate/pitch overrides.

## Consequences

- Conversation feels like a back-and-forth: the tutor remembers the last turn, corrects gently, and keeps the scene moving; `conversationAbility` finally moves in the signal system and can feed the lesson engine later.
- Naturalness is bounded by the device's installed voices and flutter_tts (no SSML) — sentence chunking + question-pitch is the best prosody available offline; true neural prosody needs a cloud speech provider (Phase 6).
- Scenario/vocab steering is deterministic and testable; a real vendor gets richer, free-form dialogue from the same prompt.
