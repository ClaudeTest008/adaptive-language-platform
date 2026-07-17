# Project Status

**Phase:** Phase 8 — Production Readiness (demo-mode slice complete; Firebase infra remaining)
**Last updated:** 2026-07-17

## Completed

- Phase 13 — conversational AI + Kindle reading (2026-07-17, UX only, branch `feature/phase13-conversational-ai`, includes Phases 11–12):
  - Tutor **voice conversation state machine** (Idle/Listening/Processing/Speaking/Error) with a live status pill; **press-and-hold** mic (hold-to-talk, release-to-send) and **barge-in** (mic press cuts off AI speech → back to Listening).
  - **Speech-engine abstraction**: `SpeechEngine` descriptor on the seam (Demo/Android Neural/iOS Enhanced/Cloud) — UI depends on the abstraction; a neural/cloud provider swaps in behind the same `speechServiceProvider`.
  - Reader: Kindle-style **Español / Both / English** display toggle (translation stays secondary) + **bookmark** action (on top of the audiobook player from Phase 12).
  - Home: collapsed **Speaking** + **Conversation** sections with one-tap launchers.
  - Library: cards show **author** + **estimated reading time** (`Story.author`, `Story.readingMinutes`).
  - 201 tests green; analyze clean; emulator-verified (reader Español/Both/English toggle + bookmark + audio player; tutor press-hold → red "Listening…" state) light + dark; core zero-diff.
  - Known limits (honest): the full **Reading Companion** (ask-in-book overlay) is **not built**; the Library is richer cards + CEFR sections, not the full shelf taxonomy (Continue Reading / Recently Read / Bookmarks with persistent progress — persistence needs a store, out of scope); reader panes don't scroll independently (single scroll); STT can't be exercised on the emulator (no mic) so the Listening→Processing→Speaking round-trip is verified by the state UI + code, not live transcription; tutor personality still light; audiobook `pause` best-effort.

- Phase 12 premium UX — home / reading / voice (2026-07-17, UX only, branch `feature/phase12-premium-ux-ai-experience`, includes Phase 11):
  - Warm light theme (soft warm-gray surfaces vs harsh white).
  - Compact dashboard: greeting header + language/CEFR pills + Continue-learning button, then collapsible sections (Today's plan open by default; Skill mastery / Teacher notes / Reading recommendation collapsed, animated ExpansionTile).
  - Story reader audiobook player: play/pause/stop/prev/next paragraph + 0.8×–1.5× speed; Stop halts immediately; audio stops on page turn. Speech seam gains `pause()`.
  - Tutor mic barge-in (tap interrupts AI speech instantly).
  - Reading Library (renamed from Stories) + new public-domain classic Lazarillo de Tormes (B1) w/ glossary + quiz.
  - 201 tests green; analyze clean; emulator-verified (warm dashboard, collapsible sections, reader audio bar) light + dark; core zero-diff.
  - Known limits (honest): audiobook `pause` is best-effort (engine-dependent; Stop always works); the full press-and-hold voice-conversation loop with Listening/Processing/Speaking states is not built (barge-in stop + status label only); tutor personality still light; category taxonomy (Classics/Modern/etc.) shown as CEFR-level sections, not separate shelves; Platero y Yo omitted (still in copyright).

- Phase 11 — experience overhaul (2026-07-17, UX only, branch `feature/phase11-experience-overhaul`, includes Phase 12):
  - Stories rewritten as multi-sentence **narratives** (3–4 sentences/page); reader **redesigned** — swipeable PageView with smooth transitions, large book-like target text, translation demoted to secondary muted body, slim animated progress + "n/N" counter, generous whitespace over the atmospheric backdrop (fewer containers).
  - Voice: `spokenText` strips bullets + emoji too; TTS slightly slower + longer breaths (warmer). Speaking feedback = warm coaching lines by score band + count-up score animation.
  - Motion: reader page transitions, animated progress, speaking score count-up; roomier tutor bubbles.
  - Verified on emulator (register→onboarding→Stories→narrative reader swipe) in light + dark; 201 tests green; analyze clean; core zero-diff.
  - Scope note (honest): this is a focused experience pass — the reader/stories are fully reworked; Lab/Goals/Onboarding/Tutor already carry the Phase-10 Hume atmosphere and got spacing/typography/motion nudges rather than ground-up redesigns. Tutor *personality* rewrite (warmer demo replies) was left light to avoid destabilizing the validated tutor flow.

- Phase 12 — classic stories + quiz + voice + Stories usability (2026-07-17, branch `feature/phase12-stories-voice-usability`):
  - Content: 3 famous public-domain stories adapted as graded readers — A1 fable (La liebre y la tortuga), A2 legend (La leyenda de la Llorona), B1 Don Quixote (los molinos de viento) — with key-words glossaries + comprehension questions in `assets/stories/es-for-en.json`.
  - Model: `Story.vocabulary`/`Story.questions` (optional; legacy stories unaffected); reader Key-words bottom sheet + end-of-story comprehension quiz (scored, coloured feedback).
  - Usability: Stories list grouped under CEFR-level headers, Quiz badge on cards.
  - Voice: `spokenText` turns em/en dashes (Spanish dialogue) + ellipses into natural pauses.
  - 201 tests green; analyze clean; emulator-verified (onboarding→Stories→Don Quixote read→Key words→quiz).
  - Note (honest): the "English words in Spanish sound robotic" issue is a platform-TTS limitation — a single utterance can't switch language mid-sentence; the fix reduces mis-read punctuation but true per-word language switching needs a cloud neural provider (Phase 8 seam).

- Phase 10 — onboarding + Hume visual maturity (2026-07-17, UI only, branch `feature/phase10-hume-visual-maturity-onboarding`):
  - First-run onboarding (`/onboarding`, gated by `onboardingSeenProvider`): immersive 3-step atmospheric flow (welcome → target language → daily minutes + target CEFR level) writing the live `selectedLanguage`/`learnerGoals` providers; segmented progress, full-width CTA.
  - UI kit: `AtmosphericBackground` (dark-first gradient + colour glows), `GlassCard` (frosted backdrop-blur surface + hairline border), `_fadeThrough` shared-axis route transitions. Applied atmospheric backdrops across Lab/Tutor/Stories/Speaking/Story-reader; glass on plan + skill-mastery cards + onboarding.
  - Verified on emulator: full flow register → onboarding (3 pages) → dashboard, light + dark; atmosphere/glass render, dark-mode audited. 199 tests green; analyze clean; core zero-diff.

- Phase 9 — deeper premium redesign + consistency (2026-07-17, UI only):
  - Shared UI kit `presentation/ui.dart`: `AppSpace`/`AppRadius`/`AppMotion` tokens, reusable `GradientHero` (soft shadow + glass sheen; dedupes 3 heroes), frosted `GlassPill`, `FadeInUp` entrance (curve-interval stagger, no timers).
  - Applied across dashboard (staggered sections, hero depth), tutor mode grid + hero + chat bubbles, stories (gradient tiles, cascade), speaking intro (gradient halo), story reader (per-phrase fade). Theme: card depth (shadow, no tint) + consistent radii.
  - Verified on emulator: dashboard (light + dark), tutor grid, stories — depth/motion render, dark-mode audited, no regressions. 198 tests green; analyze clean. Zero-diff on core (`lib/adaptive/`, `lib/ai/`).
  - Note: emulator was crash-prone this session (AVD is `Medium_Phone`, not the stale `flutter_emulator`); speaking/story-reader polish is code-reviewed + shares the same kit.

- Phase 8 polish — input/voice/UI (2026-07-17):
  - Voice: `spokenText` normalizes markdown before TTS (never voices `*`, `` ` `` or heading/list markers), Spanish + English, keeping `¿¡?!` for prosody. On top of existing warm-voice selection + clause-chunked prosody.
  - Chat: `**bold**`/`*italic*` render as real emphasis (no literal asterisks); soft bubble shadow.
  - Input: Flutter floating selection toolbar suppressed on the tutor reply + practice fields; premium filled inputs (dropped hardcoded outline); reply send unfocuses so the keyboard dismisses cleanly; voice mic docked bottom-left of the reply row.
  - Theme: refined typography (tighter headings, roomier body).
  - Verified on Android emulator (Teacher session: bold renders, no floating toolbar on long-press, clean keyboard dismiss on send); 198 tests green; analyze clean.
  - Note: the device's Gboard floating-keyboard toolbar is a system keyboard mode, outside app control.

- Phase 8 — Production Readiness demo slice (2026-07-17, ADR-0026):
  - Ingestion loop closed: `lib/language/content_merge.dart` `mergeApprovedContent` attaches approved, unmapped vocabulary/phrases/idioms as new concept/phrase nodes under a synthesized `<lang>:<level>:vocabulary:ingested` domain — they generate exercises like any authored node and project onto the core unchanged; `storyFromApproved` turns approved sentences into a "From your content" story. Base curriculum never mutated.
  - `approvedContentProvider` (durable, resets on language switch): Content Studio appends on approve / removes on reject; `curriculumProvider` and `storiesProvider` watch it, so approved items surface in practice, stories and the plan immediately. Review queue stays the only gate.
  - Learner goals (`learnerGoalsProvider`: minutes/day + target CEFR level, in-memory): `availableMinutesProvider` reads the goal (Daily Lesson Engine budgets to it), `storiesProvider` caps at the target level, tutor goal string reflects it. `/goals` screen (minutes slider + level chips) reachable from the Lab app bar.
  - `PRODUCTION_CHECKLIST.md` — pre-launch tracker (persistence swap, real speech/AI providers, iOS parity, analytics).
  - Verified: `flutter analyze` clean; 195 tests green (9 new); Android emulator — set goals (25→50 min) re-budgets Today's plan to 50 min; target level surfaces A2 stories.

- Phase 7 — Content Ingestion + input cleanup (2026-07-17, ADR-0025):
  - Language content extractor (`lib/language/ingestion.dart`): pasted target-language text → review candidates (vocabulary, phrases, example sentences, idioms, cultural notes) + CEFR difficulty + topics, mapped to curriculum concept ids where recognized. Deterministic.
  - Human review queue (`ContentReviewLog` + repository seam, in-memory demo) — approve/reject; nothing enters the curriculum unreviewed.
  - Admin Content Studio (`/content`, gated by `authState.isAdmin`, reachable from the Lab app bar): paste or "Use sample" → extract → preview grouped by kind with mapped/new status and per-candidate approve/reject.
  - Input cleanup: practice unfocuses on submit and on advancing, so the system keyboard never lingers as a "floating bar"; it reopens only on field tap. Voice/mic already bottom-docked.
  - Four new narrative stories (2×A1, 2×A2: market, park, morning train, birthday fiesta).
  - Verified: `flutter analyze` clean; 186 tests green (10 new); Android emulator — Content Studio extracts 34 candidates (A1, topics, vocab + phrases with review actions) from the sample passage.

- Phase 6 — Speech & Pronunciation depth + premium UI (2026-07-17, ADR-0024):
  - Phoneme-aware pronunciation scoring (`scorePronunciationDetailed`): per-word alignment + normalized edit distance over phonetically-folded forms (silent h, b/v, y/ll, qu/k, z/c→s, accents); near misses get partial credit; per-word ✓/✗ feedback in the speaking screen.
  - Listening recognition exercise (`ExerciseType.listening`): hear a spoken word (hidden audio), pick which word it was; auto-plays + "Play again"; new `listeningRecognition` signal via `recordAnswer(listening: true)`.
  - `pronunciationConfidence` + `conversationAbility` now weight the daily lesson — speaking/conversation blocks grow when those signals are low.
  - Voice: per-language prosody, clause-level chunking with punctuation-sized breaths, question rise/slow + exclamation lift.
  - Premium UI: pill NavigationBar with select-only labels, flat app bars, rounded filled buttons + filled inputs; no floating elements; keyboard only on field focus.
  - Verified: `flutter analyze` clean; 176 tests green (13 new); Android emulator — premium nav + cards, plan intact, speaking drill with prosodic TTS.

- Phase 5 — Conversation Engine + voice naturalness (2026-07-17, ADR-0023):
  - Scenario-driven multi-turn dialogue for Conversation + Immersion: `TutorContext` carries scenario + weak-concept `targetVocab`; `pickScenarioConceptId` weights scenarios toward weak concepts; the tutor reacts to the learner's last message, recasts errors in-reply (e.g. soy cansado → tengo sueño), weaves target vocab, progresses the scene, ends with a follow-up.
  - `conversationAbility` signal: `afterConversationTurn` EWMA + `conversationTurnQuality` (length + target-vocab use); recorded per learner turn on the scenario concept (signal-only; core untouched).
  - Wired: Conversation plan block launches a Conversation session; DemoTutorModel rewritten for contextual multi-turn replies; enriched scenario data ("At the café", "Making plans", "At the meetup").
  - Voice: sentence-chunked speech with breaths, question-pitch lift, full volume, warmer defaults, on top of enhanced-voice selection.
  - Verified: `flutter analyze` clean; 165 tests green (11 new); Android emulator — Conversation opened with weak-weighted scenario + vocab, gentle recast of a live "soy cansado" turn.

- Phase 4 — Daily Personalized Lesson Engine + content/voice polish (2026-07-17, ADR-0022):
  - `buildDailyLesson` replaces the preview heuristics: weighted, time-budgeted blocks from misconception repair (first), spaced-repetition due concepts, weakest skills, low pronunciation confidence, a concept-overlapping story, and a conversation tail. Learning DNA traits shape the weights (repeatsMistakes→repair, benefitsFromRepetition→review, strugglesUnderTimePressure→fewer/longer). Each block carries a plain-language reason + a launchable `LessonActivity`.
  - Tappable Today's-Plan blocks launch the right activity (practice / Speaking tab drill / story reader / Tutor tab). Engine stays pure — provider computes due concepts from core `ConceptStats`; core untouched.
  - Enriched stories: narrative mini-adventures ("El secreto del camarero", "La mañana de Pedro", "The first hello") with larger readable phrase chunks (≥6 words) and dual display.
  - Warmer TTS: SpeechService gains rate/pitch params; the adapter picks an enhanced/neural voice per language and uses a warmer default rate/pitch.
  - Verified: `flutter analyze` clean; 155 tests green (8 new lesson-engine + enriched-story tests); Android emulator run.

- Content & Voice — stories, speaking, tutor voice, nav shell (2026-07-16, ADR-0020/0021):
  - Short Stories: `lib/language/story.dart` + `assets/stories/` seeds (level-matched, phrase-by-phrase reader with target/translation + per-phrase and whole-story text-to-speech); Stories tab; Today's-Plan story recommendation.
  - Speaking practice: `lib/language/speaking.dart` (graph-derived drills, accent-folded token-overlap scoring); hear-the-target TTS, tap-to-speak mic, score → `pronunciationConfidence` signal + a real core AnswerEvent (mastery/DNA move); Speaking tab.
  - Tutor voice: speak-aloud on every tutor bubble, "Voice replies" auto-speak toggle, mic dictation into the reply field — same modes, now audible.
  - Speech seam: `lib/language/speech.dart` (`SpeechService`) + `infrastructure/platform_speech_service.dart` (flutter_tts + speech_to_text, best-effort); `NoopSpeechService` for tests; `available` guards voice UI on unsupported platforms.
  - UI: bottom `NavigationBar` shell (Lab / Stories / Speaking / Tutor) replaces the floating action button; keyboard shows only on field focus.
  - Verified: `flutter analyze` clean; 147 tests green (10 new content/speaking/controller tests); Android `RECORD_AUDIO` permission + recognizer query added.

- Phase 3 dialogue depth + Android verification (2026-07-16, ADR-0018 addendum):
  - Per-mode dialogue plans in every tutor prompt (`Session flow:` + `MODE:` tag); DemoTutorModel now composes six mode-true strategies (Teacher lesson w/ check question, Conversation scenario turns, Coach minute-plans from real skill percentages, Socratic single-question chains, Grammar minimal pairs, Immersion target-language-only), multi-turn aware.
  - Immersion language-purity validation: native-stopword gate in `validateTutorReply` (≥2 distinct native function words → rejected).
  - Learning DNA live: traits recomputed by the core engine after every answer, fed into every TutorContext.
  - UI: typing indicator (pulsing dots), avatar chat bubbles with asymmetric corners; Today's Plan blocks tappable (launch focused practice); exercise sessions interleave types.
  - Verified: `flutter analyze` clean; 137 tests green (5 new); **Android emulator run verified with screenshots** — login, Language Lab, tutor mode selector, live Teacher session with misconception repair all rendering the teal theme correctly on 1080×2400 (incl. dark mode).

- Product rebrand — language-first navigation + immersion UI (2026-07-16, ADR-0019):
  - Language Lab is now the app home (`/`); exam-era routes (practice/mock/bookmarks/search/admin) retired from navigation; login/settings/web manifest/index rebranded — no exam-flavored surface reachable (verified by adversarial sweep).
  - Multi-language selector (`availableLanguages` registry + `selectedLanguageProvider`): Spanish 🇪🇸 / English 🇬🇧, per-language demo seeds; fresh learner state per switch (review found + fixed cross-language contamination and count inflation; regression-tested round trip).
  - Immersion theme: teal M3 palette, gradient hero + tutor hero cards, frosted pills, rounded cards, AI Tutor FAB; dashboard reordered — tutor hero, Today's plan, practice CTA, skill mastery, teacher notes.
  - Tutor goals now derive from the selected curriculum ("Reach A2 {language}").
  - Verified: `flutter analyze` clean; 132 tests green; web boots cleanly, zero console errors.

- Phase 3 foundation — AI tutor (2026-07-16, ADR-0018):
  - `lib/language/tutor.dart`: `TutorContext` snapshot assembly (skill mastery, weakest concepts, misconceptions, signals, goals, Learning DNA, focus-concept graph slice with relations + pattern family); six mode contracts with distinct personas; `tutorSystemPrompt` serializes learner context; `validateTutorReply` gates every output (structure + grounding), rejected output replaced by safe fallback.
  - Provider-blind: `LanguageTutor` consumes any `AiChatModel` (`lib/ai/` untouched); `tutorModelProvider` = vendor swap point; `DemoTutorModel` composes deterministic teacherly replies from the same prompts a vendor would get (Teacher-mode live flow: misconception repair first, then pattern family).
  - UI: `/language/tutor` — gradient hero with live learner stats, six-mode grid, chat session with context chips (mode, focus, misconception count); AI Tutor CTA beside practice on the Language Lab dashboard.
  - Verified: `flutter analyze` clean; 131 tests green (11 new: context assembly, mode prompts, validation, tutor service, demo flow, widget); web boots cleanly.

- Phase 2 finish — text-first exercise flows + demo readiness (2026-07-16, ADR-0017):
  - Exercise generation derived from curriculum data (`lib/language/exercises.dart`): multiple choice, fill-in-blank, translation, sentence building, reading comprehension; deterministic (seeded shuffles); repair concepts sort first; diacritic-preserving answer checks.
  - `/language/practice` session screen: animated progress, per-type inputs (option cards, text field, word-bank chips), inline feedback with teacher notes from the misconception engine, animated score summary. Dashboard "Practice your weak spots" CTA (focused on the repair block).
  - `recordAnswer` returns detected misconceptions (inline feedback), awaits controller init (cold deep links safe), detects over the concept lineage — an error on "Tengo hambre" implicates `tener-states` — and registers transfer signals on the attributed ancestor.
  - Seed curricula gained three example sentences (data-only) to enrich the exercise pool.
  - Verified: `flutter analyze` clean; 120 tests green (10 new); web app boots cleanly (`flutter run -d web-server`, zero console errors, title "Adaptive Language Platform").

- Phase 2 core — misconception engine + signal tracking + Language Lab UI (2026-07-16, ADR-0016):
  - Misconception engine: graph-authorized detection (interference relations, transfer traps), recorded separately from mistakes with explanation, source, pattern family; occurrences merge by stable id.
  - `LanguageConceptSignals.afterAnswer` EWMA updates (recall difficulty/speed, usage frequency, transfer errors, native interference) + `LanguageSignalsStore`; persistence seams with in-memory demo implementations.
  - Core engine reused unchanged: `LearnerEngine(graph: languageGraph.toCoreGraph())`, answers exercise full concept lineage.
  - Language Lab UI: `/language` (animated per-skill mastery, misconception Teacher Notes, repair-first daily lesson preview) + `/language/concept/:id` (signals, graph relations, pattern family, live simulate buttons); entry card on the main dashboard; app title now "Adaptive Language Platform".
  - Verified: `flutter analyze` clean; 110 tests green (9 tracking + 2 widget tests new); web app boots and renders (manual screenshot blocked by tooling, screens verified by widget tests).

- Phase 1 — Language domain model (2026-07-16, ADR-0015):
  - `lib/language/` pure-Dart layer: 11-tier language hierarchy with hierarchical concept ids, typed nodes (grammar concepts with transfer traps, vocabulary with lemma/translations/frequency, phrases, examples, exercises, conversations), CEFR levels, 10 skills.
  - `LanguageKnowledgeGraph`: typed relations (requires, buildsOn, interferesWith, culturalContext, falseFriend, relatedTo); `toCoreGraph()` projection — core engine consumes language structure unchanged (zero diffs under `lib/adaptive/`).
  - Language memory signals (`LanguageConceptSignals`) beside the core LearnerModel; per-skill mastery aggregation (`skillMastery`, `weakestSkills`).
  - CEFR curricula as JSON data: schema + loader + `es-for-en` / `en-for-es` seeds (tener-states misconception family, ser/estar, embarazada + actually false friends, pro-drop interference, cultural context).
  - Firestore schema drafts: `docs/database/05-language-schema.md`.
  - Verified: `flutter analyze` clean; 99 tests green (89 inherited unchanged + 10 new in `test/language_domain_test.dart`).

- Phase 0 — Fork foundation (2026-07-12):
  - Repository `adaptive-language-platform` created as history-preserving fork of `adaptive-exam-platform` (ADR-0014). Independent remote; original repo untouched.
  - Product identity: README, AI_CONTEXT, ARCHITECTURE, ROADMAP, PROJECT_STATUS, TASKS, CHANGELOG rewritten for the language platform.
  - ADR structure continued: 0001–0013 inherited (binding for the Adaptive Learning Core), 0014 records the fork decision.

## In Progress

- Phase 8 infra (blocked on Firebase keys): Firestore repository swap behind the existing seams, real speech/AI vendor adapters, analytics + crash reporting, iOS/web parity, onboarding, package rename. See `PRODUCTION_CHECKLIST.md`.

## Inherited at Fork Point (commit 3b597b2 lineage)

Working Adaptive Learning Core from the exam platform, reused as-is:

- Flutter app (`app/flutter/`, Flutter 3.44.5, Riverpod 3, go_router 16) in demo mode (ADR-0006).
- Adaptive engine (`lib/adaptive/`, ADR-0008): learner model, knowledge graph, spaced repetition, confidence, selector, study plans, Learning DNA — pure Dart.
- AI orchestration (`lib/ai/`, ADR-0010): AiChatModel vendor seam, AiOrchestrator, FakeChatModel.
- Content intelligence (ADR-0011): chunked imports, quality engine, document ingestion, review queue.
- Content Studio (`/admin`, ADR-0007/0009): CRUD, versioning, bulk ops, import analytics.
- Enterprise platform (ADR-0012/0013): tenant isolation (CI-tested rules), library inheritance, curriculum hierarchy, search/notification seams.
- 89 Flutter tests + 22 Firestore rules tests green at fork point; CI workflow inherited.

Note: inherited domain code still uses exam vocabulary (questions, exams, topics). Remodeling to the language hierarchy is Phase 1 — docs describe the target; code catches up phase by phase.

## Next

- Phase 8 infra: Firebase integration + Firestore repository swap (schema drafted, seams ready), real speech/AI/analytics providers, iOS/web parity, package rename. Also: AI extractor over the review queue, cloud speech models, tutor history persistence. See ROADMAP.md + PRODUCTION_CHECKLIST.md.

## Local Dev

Flutter SDK at `C:\Users\Admin\flutter` (3.44.5 stable). Run web: `flutter run -d web-server --web-port=5317` in `app/flutter/`.

## Known Limitations

- Language Lab starts demo-seeded (deterministic scripted learner per language, reseeds on restart/switch); practice sessions layer real answer events on top. Exam-era screens are unrouted dead code until the package rename deletes them (backlog).
- Exercise pool bounded by curriculum richness (A1 slices) until Phase 7 content ingestion.
- Firebase production integration deferred to Phase 8 (runbooks in `docs/deployment/`).
- `docs/product/`, `docs/architecture/`, `docs/database/` subtrees still describe the exam domain; rewritten incrementally as each phase touches them.
