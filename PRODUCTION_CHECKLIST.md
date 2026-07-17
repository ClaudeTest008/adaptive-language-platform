# Production Readiness Checklist

Pre-launch checklist for the Adaptive Language Platform. The app runs
today in **demo mode** (in-memory repositories, ADR-0006). This tracks
what must land before a real launch, grouped by area. Status: ✅ done ·
⏳ ready-but-pending-keys/infra · ⬜ not started.

## Persistence (Firebase / Firestore swap)

- ⏳ Firestore repository implementations behind the existing interfaces
  (`LearnerModelRepository`, `MisconceptionRepository`,
  `LanguageSignalsRepository`, `ContentReviewRepository`, tutor/goals
  stores). Swap point = provider bindings only; demo impls prove the
  shapes. Schema drafted in `docs/database/05-language-schema.md`.
- ⏳ Firebase project + `flutterfire configure` (human runbook:
  `docs/deployment/01-firebase-setup.md`).
- ⬜ Migrate approved-content merge + learner goals to persisted docs
  (currently in-memory per session; the merge/goals logic is final).
- ✅ Every write path already goes through a repository seam — no direct
  store access from UI or language logic.

## Speech (real provider)

- ✅ `SpeechService` seam with a platform adapter (flutter_tts +
  speech_to_text) and prosodic TTS.
- ⏳ Cloud neural speech provider for higher-quality voices + real
  phoneme/prosody pronunciation scoring (replaces the on-device
  edit-distance approximation). Binds behind the same seam.
- ⬜ Microphone permission UX polish + graceful denial (seam already
  degrades to null transcript; add a user-facing prompt).

## AI tutor (real vendor)

- ⏳ Anthropic/OpenAI/Gemini adapters behind `tutorModelProvider`
  (blocked on API keys). `DemoTutorModel` consumes the same prompts;
  swap is a one-line binding.
- ✅ Output validation gate (structure + grounding + immersion purity)
  runs before any reply reaches the learner.

## Content pipeline

- ✅ Text ingestion → review queue → approve → merged into live
  curriculum/stories (ADR-0025/0026).
- ⏳ AI extractor feeding the same review queue (over `AiChatModel`).
- ⬜ Binary formats (PDF/DOCX/audio transcript) ingestion.

## Platform parity

- ✅ Android verified end-to-end on emulator.
- ⬜ iOS build + parity pass (Info.plist display name, mic permission
  string, TTS voice availability). Not buildable on the Windows dev box.
- ⬜ Web build smoke (flutter_tts/speech_to_text web support; `available`
  already guards voice UI).

## Analytics & ops

- ⬜ Analytics hooks (session start, lesson-block start, exercise
  answered, tutor turn, pronunciation attempt) — a typed event catalog,
  no PII, wrapping the inherited analytics wrapper.
- ⬜ Crash reporting (Crashlytics) wired at app root.
- ⬜ Remote config for feature flags (voice on/off, AI provider).

## Quality gates

- ✅ `flutter analyze` clean; 195+ tests green; CI workflow inherited.
- ✅ Adaptive Learning Core untouched since fork (empty
  `git diff 3b597b2..HEAD -- lib/adaptive lib/ai`).
- ⬜ Widget/integration tests for the STT-dependent flows on a device
  with a real recognizer (emulator lacks a mic).
- ⬜ Package rename `adaptive_exam_platform` → `adaptive_language_platform`
  + delete unrouted exam-era screens.

## UX / launch polish

- ✅ Language-first navigation, premium NavigationBar, filled inputs,
  no floating elements; keyboard shows only on field focus.
- ✅ Learner goals surface (minutes/day + target level) driving the plan.
- ⬜ Onboarding flow (pick target language + native language + goals on
  first run) — today the learner lands on a seeded demo.
- ⬜ Localization of the UI chrome (target language and UI locale are
  already independent axes).
