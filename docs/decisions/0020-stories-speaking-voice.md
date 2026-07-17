# ADR-0020: Short Stories, Speaking Practice, Voice

**Status:** Accepted
**Date:** 2026-07-16

## Context

The learner surface needed reading, speaking, and voice: level-matched short stories, a pronunciation-scored speaking drill, and voice I/O for the tutor. All three need text-to-speech and speech recognition — platform plugins that break the pure-Dart, testable language layer if used directly.

## Decision

1. **Speech is a seam** (`lib/language/speech.dart`, `SpeechService`: speak / stop / listen / available), exactly like the `AiChatModel` seam. The only file touching flutter_tts + speech_to_text is `infrastructure/platform_speech_service.dart`; `NoopSpeechService` (scriptable transcript) drives tests offline. Every plugin call is best-effort — failure degrades to a no-op or null transcript, never a crash. `available` lets the UI hide voice affordances on web/unsupported devices.
2. **Stories are data** (`lib/language/story.dart` + `assets/stories/<lang>.json`): a story is an ordered list of phrases (target text + native translation + concept ids). Pure model + `parseStories`; `recommendedLevel` (CEFR anchor, nudged down one level when the learner is struggling — i+1, not i+3) and `storiesForLevel` pick the queue. Reading references concept ids so it feeds the graph and the Today's-Plan recommender. The reader shows one phrase at a time, target large over translation, with per-phrase and whole-story TTS.
3. **Speaking scores through the signal system** (`lib/language/speaking.dart`): drills are generated from graph vocabulary/phrases/short sentences (focus concepts first, deterministic). `scorePronunciation` is token-overlap, accent-folded (recognizers rarely return diacritics) — a proxy for real phoneme scoring (Phase 6). Each attempt records `pronunciationConfidence` (new `afterPronunciation` EWMA on the existing signal) AND applies a core `AnswerEvent` (a spoken attempt is production evidence), so mastery and Learning DNA move too. The core engine is untouched.
4. **Tutor voice reuses the mode system**: speak-aloud on each tutor bubble, a "Voice replies" toggle that auto-speaks new tutor turns, and a mic that dictates the learner's reply into the text field. No new tutor logic — the same `TutorContext` and validated replies, now audible. Replies are spoken in the target-language voice (`bcp47` per curriculum row).

## Consequences

- `flutter_tts` + `speech_to_text` added; Android gains `RECORD_AUDIO` + a recognizer `<queries>` entry. Web builds keep working (both plugins support web; `available` guards the rest).
- Pronunciation scoring is coarse (token overlap) until Phase 6 speech models; the seam and signal are final.
- Emulators without a mic/recognizer return null transcripts — the UI stays usable (drills advance, voice affordances no-op) rather than blocking.
- Story/speaking demo state is per-run like the rest of demo mode; persistence lands with the Firestore swap (Phase 8).
