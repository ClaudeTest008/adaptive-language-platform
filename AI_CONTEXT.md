# AI Context

This file is the permanent memory of the project for AI development sessions. Read it at the start of every session. Keep it accurate and short.

## What This Project Is

**Adaptive Language Platform** — AI-powered adaptive language learning system:

- Flutter client app (`app/flutter/`)
- Backend services (`backend/`)
- Serverless functions (`cloud_functions/`)
- Adaptive Learning Core (inherited, `lib/adaptive/` + `lib/ai/`) — see Lineage below

Goal: a personalized AI language teacher, not a flashcard app. The adaptive engine tracks mastery of language **concepts** (grammar patterns, vocabulary, skills), not individual exercises.

## Lineage (ADR-0014)

Forked 2026-07-12 from `adaptive-exam-platform` with full git history. Everything up to commit `3b597b2` is inherited exam-platform work. The Adaptive Learning Core is reused, not rewritten:

- `lib/adaptive/` — learner model, knowledge graph, scheduler, selector, confidence, Learning DNA (pure Dart)
- `lib/ai/` — AiChatModel provider seam, AiOrchestrator
- `lib/application/` — import pipeline, quality engine, document ingestion (becomes language content intelligence)
- `lib/domain/` + `lib/infrastructure/` — Clean Architecture repository pattern, demo mode (ADR-0006)
- Content Studio, multi-tenancy, search/notification seams

Layering: **Adaptive Learning Core → Adaptive Language Platform → Language Learning Features.** Extend the core with language signals; never rewrite it. Keep language-specific features separate from the core.

## Rules for AI Sessions

1. Read `PROJECT_STATUS.md` and `TASKS.md` before starting work.
2. Complete one well-defined task at a time; do not start unrelated work.
3. Read only the documentation referenced by the current task.
4. Never recreate files that already exist; continue from the current state.
5. Record architectural decisions in `docs/decisions/` (one file per decision).
6. Update `PROJECT_STATUS.md`, `TASKS.md`, and `CHANGELOG.md` when a milestone or task completes.
7. Keep commits small and focused; report the commit hash after each commit.
8. Never push to or modify the original `adaptive-exam-platform` repository.

## Language Learning Model

Knowledge hierarchy (replaces exam category → topic → question):

Language → Level → Skill → Domain → Topic → Grammar Concept → Vocabulary Concept → Phrase → Example Sentence → Exercise → Conversation

Skills with independent mastery: Vocabulary, Grammar, Reading, Writing, Listening, Speaking, Pronunciation, Conversation, Culture, Comprehension.

Language-specific memory signals (extend LearnerModel, don't replace): vocabulary strength, grammar confidence, recall speed, pronunciation confidence, listening recognition, speaking ability, common mistakes, native-language interference, retention decay.

Misconceptions tracked separately from mistakes (e.g. "Yo soy cansado" = English grammar transfer → teach `tener` pattern family).

AI tutor modes (architecture in Phase 3): Teacher, Conversation, Coach, Socratic, Grammar, Immersion. Tutor consumes learner history, knowledge graph, Learning DNA, mistakes, weak concepts, goals, learning style. Provider-independent (OpenAI/Anthropic/Gemini/local/speech/translation); all AI output passes validation.

## Current State

- Phase 4 — Daily Lesson Engine (2026-07-17, ADR-0022): `lib/language/lesson.dart` `buildDailyLesson` (replaces `previewDailyLesson`) — weighted time-budgeted blocks (repair/review/grammar/vocab/pronunciation/story/conversation), `LessonBlock` now carries `reason` + `activity` (LessonActivity: practice/speaking/story/tutor) + `storyId`; DNA traits shape weights; pure (no core import — provider `dailyLessonProvider` computes `dueConceptIds` from core ConceptStats.isDue/lapses, feeds signals/traits/stories/accuracy/`availableMinutesProvider`). Dashboard `_LessonPreviewCard` shows reasons + `_launchBlock` dispatches by activity; old `_StoryRecommendation` removed. Enriched story seeds (narrative, ≥6-word phrases). SpeechService.speak gains rate/pitch; PlatformSpeechService picks enhanced/neural voice + warm defaults (rate 0.44, pitch 1.05). 155 tests (language_lesson_test.dart new). Old lesson tests migrated to buildDailyLesson.

- Content & Voice (2026-07-16, ADR-0020/0021): Stories (`lib/language/story.dart`, `assets/stories/`), Speaking (`lib/language/speaking.dart` — `scorePronunciation` accent-folded token overlap), Speech seam (`lib/language/speech.dart` `SpeechService`; real adapter `infrastructure/platform_speech_service.dart` over flutter_tts+speech_to_text; `NoopSpeechService(scriptedTranscript:)` for tests). Providers: `storiesProvider`, `speechServiceProvider`, `speakingProvider`, `languageBcp47Provider`; `LanguageLearnerController.recordPronunciation`; `LanguageConceptSignals.afterPronunciation`. UI = bottom-nav `HomeShell` (Lab/Stories/Speaking/Tutor, `homeTabProvider`), FAB removed; tutor voice (speak bubbles + "Voice replies" auto-speak + mic dictation). Android `RECORD_AUDIO` added. 147 tests. Gotcha: widget tests over rootBundle-loaded stories/speaking are flaky under the shared binding — cover that logic in `language_content_test.dart` (unit/controller), verify screens on emulator. `_app` in language_screens_test overrides `speechServiceProvider` with NoopSpeechService.

- Phase 3 dialogue depth (2026-07-16, ADR-0018 addendum): tutor prompts carry `MODE:` tag + per-mode `Session flow:` dialogue plans; `validateTutorReply` adds immersion purity gate (≥2 distinct native stopwords → reject; `_stopwords` map in tutor.dart); `LanguageLearnerState.traits` = live Learning DNA (engine.learningDna after every answer) fed to TutorContext; DemoTutorModel = six mode-true strategies, multi-turn aware via assistant-turn count. UI: typing indicator, avatar bubbles, tappable plan blocks, exercise-type interleaving in generateExercises. 137 tests green. Android emulator verified (AVD `flutter_emulator`; pin `adb -s emulator-5554` — ghost offline 5556 may appear; screencap workflow documented in memory).

- Rebrand complete (2026-07-16, ADR-0019): Language Lab = home (`/`), exam routes retired (screens unrouted dead code until package-rename sweep — TASKS Active), multi-language selector (`availableLanguages` + `selectedLanguageProvider`; per-language `_seedScripts`; `_init` RESETS misconception/signal stores before seeding — shared in-memory repos otherwise leak the previous language's state across switches, regression-tested), teal immersion theme, tutor hero + FAB, tutor goals = "Reach A2 {languageName}". 132 tests green.

- Phase 3 foundation complete (2026-07-16, ADR-0018): `lib/language/tutor.dart` — `TutorContext` (skill mastery, weak concepts, misconceptions, signals, goals, DNA traits, focus graph slice; default focus = top misconception), `tutorSystemPrompt` (6 mode personas + `[LEARNER CONTEXT]` block), `validateTutorReply` (structure + grounding; rejected → safe fallback), `LanguageTutor` over `AiChatModel`. `lib/infrastructure/demo_tutor_model.dart` = deterministic vendor stand-in reading the same prompts. Providers: `tutorModelProvider` (vendor swap point), `tutorSessionProvider`. UI: `/language/tutor` + dashboard CTA. 131 tests green (`language_tutor_test.dart` new). Remaining Phase 3: dialogue depth per mode, immersion purity validation, tutor history persistence, vendor adapters (need API keys).
- Phase 2 COMPLETE (2026-07-16, ADR-0017 finish): `lib/language/exercises.dart` — exercises derived from curriculum data (5 text-first types, deterministic via seeded shuffles, `focusConceptIds` first, `checkAnswer` keeps diacritics); `/language/practice` (`languagePracticeProvider`, screen with inline teacher notes + score summary); dashboard CTA. `recordAnswer` now: returns detected misconceptions, awaits `_initFuture`, detects over `lineageConceptIds` (leaf-first) so child-exercise errors implicate ancestor concepts, registers transfer signals on attributed ancestors. 120 tests green (`language_exercises_test.dart` new).
- Phase 2 core (2026-07-16, ADR-0016): `lib/language/misconceptions.dart` (MisconceptionDetector — fires only on wrong answers with graph-authorized interference; MisconceptionLog merges by `conceptId|source`), `signals.dart` extended (`afterAnswer` EWMA alpha 0.3, `LanguageSignalsStore`, repository seams), `lesson.dart` (repair-first preview, Phase 4 stopgap), `lib/infrastructure/language_repositories.dart` (in-memory), `lib/presentation/language_providers.dart` (`LanguageLearnerController` — reuses unchanged core `LearnerEngine` via `toCoreGraph()`, deterministic demo seed), screens `language_dashboard_screen.dart` (`/language`) + `language_concept_screen.dart` (`/language/concept/:id`, live simulate buttons). 110 tests green (`language_tracking_test.dart`, `language_screens_test.dart` new).
- Phase 1 (ADR-0015): `lib/language/` — `entities.dart` (11-tier hierarchy, typed nodes, CEFR, 10 skills), `relationships.dart` (6 relation types, `toCoreGraph()`), `curriculum.dart` + `assets/curriculum/` seeds (es-for-en, en-for-es). Schema drafts: `docs/database/05-language-schema.md`. Core untouched since fork (verify: empty `git diff 3b597b2..HEAD -- app/flutter/lib/adaptive app/flutter/lib/ai`).
- Inherited codebase state: Flutter 3.44.5 (SDK at `C:\Users\Admin\flutter`), Riverpod 3 (`StateProvider` needs `flutter_riverpod/legacy.dart`; `AsyncValue.valueOrNull` is now `.value`), go_router 16. Swap point = providers in `lib/presentation/providers.dart`. Package still named `adaptive_exam_platform` (rename queued for when exercise flows retire exam screens). App ids are already distinct (2026-07-16): Android `applicationId` = `com.adaptiveexam.adaptive_language_platform`, iOS bundle id = `com.adaptiveexam.adaptiveLanguagePlatform` — installs coexist with the exam app; Kotlin namespace/MainActivity package intentionally unchanged until the rename sweep. CI: `.github/workflows/ci.yml`.
- Next: Phase 3 depth — mode-specific dialogue logic, immersion purity validation, tutor history persistence. Then Phase 4 lesson engine. See TASKS.md.

## Key Conventions

- Documentation lives in `docs/` split by domain; root-level files are indexes and state.
- Decision records: `docs/decisions/NNNN-title.md`. ADRs 0001–0013 inherited from exam platform (still binding for the core); 0014+ are language-platform decisions.
