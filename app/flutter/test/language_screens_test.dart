import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/infrastructure/prefs_experience_repository.dart';
import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/curriculum_intelligence.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/learning_journey_engine.dart';
import 'package:adaptive_exam_platform/language/notebook_repository.dart';
import 'package:adaptive_exam_platform/language/recommendation_engine.dart';
import 'package:adaptive_exam_platform/language/reader_intelligence.dart';
import 'package:adaptive_exam_platform/language/roleplay_engine.dart';
import 'package:adaptive_exam_platform/language/story.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_stories_screen.dart';
import 'package:adaptive_exam_platform/language/teacher_memory.dart';
import 'package:adaptive_exam_platform/language/tutor.dart';
import 'package:adaptive_exam_platform/language/speech.dart';
import 'package:adaptive_exam_platform/presentation/language_providers.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_concept_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/home_shell.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_dashboard_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_content_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_goals_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_onboarding_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_practice_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_tutor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';

Curriculum _curriculum() => _curriculumFor('es');

Curriculum _curriculumFor(String code) => parseCurriculum(
  jsonDecode(
        File(
          'assets/curriculum/${code == 'es' ? 'es-for-en' : 'en-for-es'}.json',
        ).readAsStringSync(),
      )
      as Map<String, dynamic>,
);

Widget _app(Curriculum c, Widget home) => ProviderScope(
  overrides: [
    curriculumProvider.overrideWith((ref) => Future.value(c)),
    // Tests never touch the real TTS/STT plugins.
    speechServiceProvider.overrideWithValue(NoopSpeechService()),
    // In-memory notebook store — no shared_preferences plugin under test.
    teacherNotebookRepositoryProvider.overrideWithValue(
      InMemoryTeacherNotebookRepository(),
    ),
    experienceRepositoryProvider.overrideWithValue(
      InMemoryExperienceRepository(),
    ),
    teacherMemoryRepositoryProvider.overrideWithValue(
      InMemoryTeacherMemoryRepository(),
    ),
  ],
  child: MaterialApp(home: home),
);

/// Pump until the demo seed has flowed through the controller.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1)); // finish bar animations
}

void main() {
  final curriculum = _curriculum();

  testWidgets('language dashboard renders mastery, teacher notes and lesson', (
    tester,
  ) async {
    await tester.pumpWidget(_app(curriculum, const LanguageDashboardScreen()));
    await _settle(tester);

    // Header: demo learner seeded through the real engine.
    expect(find.text('Spanish'), findsOneWidget);
    expect(find.text('A1 · CEFR'), findsOneWidget);
    // Tutor hero opens with the top misconception to repair.
    expect(find.textContaining('Wants to clear up:'), findsOneWidget);

    // Teacher's Notes lead the dashboard (expanded by default): the live
    // notebook engine estimates a working level and folds in the detected
    // misconception (tener, seen 2×) via the card below it.
    await tester.scrollUntilVisible(find.text("Teacher's Notes"), 150);
    await tester.scrollUntilVisible(
      find.textContaining('Working level: around'),
      120,
    );
    await tester.scrollUntilVisible(find.text('2×').first, 150);
    expect(find.text('2×'), findsWidgets);
    expect(find.textContaining('tener', findRichText: true), findsWidgets);

    // Progress summary: independent per-skill mastery, collapsed by default.
    await tester.scrollUntilVisible(find.text('Progress summary'), 150);
    await tester.tap(find.text('Progress summary'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Vocabulary'), 120);
    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);

    // Current focus (expanded) surfaces the live plan: repair first + minutes.
    await tester.scrollUntilVisible(find.textContaining('Repair:'), 150);
    expect(find.textContaining('Repair:'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('minutes today'), 150);
    expect(find.textContaining('minutes today'), findsWidgets);
  });

  testWidgets('dashboard surfaces the unified recommendation list', (
    tester,
  ) async {
    // Override the ONE recommendation list with a fixed, ranked set so the
    // widget is asserted deterministically (the engines' own determinism is
    // covered by language_phase32/33/34 tests).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
          speechServiceProvider.overrideWithValue(NoopSpeechService()),
          teacherNotebookRepositoryProvider.overrideWithValue(
            InMemoryTeacherNotebookRepository(),
          ),
          experienceRepositoryProvider.overrideWithValue(
            InMemoryExperienceRepository(),
          ),
          teacherMemoryRepositoryProvider.overrideWithValue(
            InMemoryTeacherMemoryRepository(),
          ),
          recommendationsProvider.overrideWith(
            (ref) async => const [
              Recommendation(
                id: 'r1',
                kind: RecommendationKind.recoverWeakConcept,
                priority: 0,
                reason: 'Revisit ser vs estar — it keeps tripping you up.',
              ),
              Recommendation(
                id: 'r2',
                kind: RecommendationKind.connection,
                priority: 3,
                reason: 'Reinforce tener by connecting it to tener hambre.',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: LanguageDashboardScreen()),
      ),
    );
    await _settle(tester);

    await tester.scrollUntilVisible(find.text('What to focus on next'), 150);
    await tester.tap(find.text('What to focus on next'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Revisit ser vs estar'),
      120,
    );
    expect(find.textContaining('Revisit ser vs estar'), findsOneWidget);
    expect(find.textContaining('Reinforce tener'), findsOneWidget);
  });

  testWidgets('tapping a recommendation routes to the matching activity', (
    tester,
  ) async {
    // A reading recommendation should send the learner to the Library tab
    // (index 1) — a pure, deterministic homeTab change, no session side effects.
    final container = ProviderContainer(
      overrides: [
        curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
        speechServiceProvider.overrideWithValue(NoopSpeechService()),
        teacherNotebookRepositoryProvider.overrideWithValue(
          InMemoryTeacherNotebookRepository(),
        ),
        experienceRepositoryProvider.overrideWithValue(
          InMemoryExperienceRepository(),
        ),
        teacherMemoryRepositoryProvider.overrideWithValue(
          InMemoryTeacherMemoryRepository(),
        ),
        recommendationsProvider.overrideWith(
          (ref) async => const [
            Recommendation(
              id: 'rd1',
              kind: RecommendationKind.reading,
              priority: 0,
              reason: 'Read a short story to grow your vocabulary in context.',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LanguageDashboardScreen()),
      ),
    );
    await _settle(tester);

    expect(container.read(homeTabProvider), 0);
    await tester.scrollUntilVisible(find.text('What to focus on next'), 150);
    await tester.tap(find.text('What to focus on next'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Read a short story'),
      120,
    );
    await tester.tap(find.textContaining('Read a short story'));
    await tester.pump();
    expect(container.read(homeTabProvider), 1);
  });

  testWidgets('dashboard surfaces learning journeys with health', (
    tester,
  ) async {
    // Fixed journey report so the card is asserted deterministically (the
    // engine's own logic is covered by language_phase32_test.dart).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
          speechServiceProvider.overrideWithValue(NoopSpeechService()),
          teacherNotebookRepositoryProvider.overrideWithValue(
            InMemoryTeacherNotebookRepository(),
          ),
          experienceRepositoryProvider.overrideWithValue(
            InMemoryExperienceRepository(),
          ),
          teacherMemoryRepositoryProvider.overrideWithValue(
            InMemoryTeacherMemoryRepository(),
          ),
          journeyReportsProvider.overrideWith(
            (ref) async => const [
              JourneyReport(
                journey: LearningJourney(
                  id: 'j1',
                  name: 'Present tense verbs',
                  stages: [],
                  progress: 0.5,
                ),
                health: JourneyHealth.accelerating,
                prediction: JourneyPrediction(nextMilestone: 'Irregular yo-forms'),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: LanguageDashboardScreen()),
      ),
    );
    await _settle(tester);

    await tester.scrollUntilVisible(find.text('Your learning journeys'), 150);
    await tester.tap(find.text('Your learning journeys'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Present tense verbs'), 120);
    expect(find.text('Present tense verbs'), findsOneWidget);
    expect(find.text('Accelerating'), findsOneWidget);
    expect(find.textContaining('Irregular yo-forms'), findsOneWidget);
  });

  testWidgets('dashboard surfaces the suggested practice scene', (
    tester,
  ) async {
    // Fixed roleplay scenario so the card is asserted deterministically (the
    // engine's own selection logic is covered by language_phase30_test.dart).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
          speechServiceProvider.overrideWithValue(NoopSpeechService()),
          teacherNotebookRepositoryProvider.overrideWithValue(
            InMemoryTeacherNotebookRepository(),
          ),
          experienceRepositoryProvider.overrideWithValue(
            InMemoryExperienceRepository(),
          ),
          teacherMemoryRepositoryProvider.overrideWithValue(
            InMemoryTeacherMemoryRepository(),
          ),
          roleplaySelectionProvider.overrideWithValue(
            const RoleplayScenario(
              kind: RoleplayKind.restaurant,
              title: 'At the café',
              setting: 'Ordering a coffee in Madrid.',
              difficulty: RoleplayDifficulty.standard,
              stages: [],
              focusConceptIds: [],
              rationale: 'You are ready to use greetings in a real scene.',
            ),
          ),
        ],
        child: const MaterialApp(home: LanguageDashboardScreen()),
      ),
    );
    await _settle(tester);

    await tester.scrollUntilVisible(find.text('Suggested practice scene'), 150);
    // The section sits low on the long dashboard; ensure the header is fully in
    // the 600px test viewport before tapping so the expand hit-test lands.
    await tester.ensureVisible(find.text('Suggested practice scene'));
    await _settle(tester);
    await tester.tap(find.text('Suggested practice scene'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('At the café'), 120);
    expect(find.text('At the café'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.textContaining('Ordering a coffee'), findsOneWidget);
  });

  testWidgets('library surfaces the reader profile once books are read', (
    tester,
  ) async {
    // Fixed story list (no rootBundle → not flaky) + fixed profile so the
    // card is asserted deterministically (engine logic covered by
    // language_phase33_test.dart).
    const story = Story(
      id: 's1',
      title: 'El viaje',
      level: CefrLevel.a1,
      phrases: [StoryPhrase(text: 'Hola.', translation: 'Hello.')],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
          speechServiceProvider.overrideWithValue(NoopSpeechService()),
          teacherNotebookRepositoryProvider.overrideWithValue(
            InMemoryTeacherNotebookRepository(),
          ),
          experienceRepositoryProvider.overrideWithValue(
            InMemoryExperienceRepository(),
          ),
          teacherMemoryRepositoryProvider.overrideWithValue(
            InMemoryTeacherMemoryRepository(),
          ),
          storiesProvider.overrideWith((ref) => Future.value(const [story])),
          readerProfileProvider.overrideWith(
            (ref) async => const ReaderProfile(
              booksRead: 2,
              readingConfidence: 0.8,
              difficultyFit: ReadingDifficultyFit.tooEasy,
              insights: ['You finish what you start.'],
            ),
          ),
        ],
        child: const MaterialApp(home: LanguageStoriesScreen()),
      ),
    );
    await _settle(tester);

    expect(find.text('Your reading'), findsOneWidget);
    expect(find.textContaining('2 books finished'), findsOneWidget);
    expect(find.textContaining('comprehension 80%'), findsOneWidget);
    expect(find.text('Ready for harder'), findsOneWidget);
    expect(find.text('You finish what you start.'), findsOneWidget);
  });

  test('tutor session runs on the packet teacher path once the brain is ready',
      () async {
    final container = ProviderContainer(
      overrides: [
        curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
        speechServiceProvider.overrideWithValue(NoopSpeechService()),
        teacherNotebookRepositoryProvider.overrideWithValue(
          InMemoryTeacherNotebookRepository(),
        ),
        experienceRepositoryProvider.overrideWithValue(
          InMemoryExperienceRepository(),
        ),
        teacherMemoryRepositoryProvider.overrideWithValue(
          InMemoryTeacherMemoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Let the demo seed + brain resolve (same settling the widgets rely on).
    await container.read(curriculumProvider.future);
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (container.read(teacherBrainProvider).value != null) break;
    }
    expect(container.read(teacherBrainProvider).value, isNotNull,
        reason: 'brain must resolve for the packet path');

    final tutor = container.read(tutorSessionProvider.notifier);
    await tutor.start(TutorMode.teacher);
    var s = container.read(tutorSessionProvider)!;
    // The packet path stores the advanced ConversationContext; the legacy
    // fallback leaves it empty — so a non-empty context proves activation.
    expect(s.conversation.turns, isNotEmpty);
    expect(s.transcript.last.$2, isNotEmpty);

    await tutor.send('Hola, quiero practicar.');
    s = container.read(tutorSessionProvider)!;
    expect(s.conversation.turns.length, greaterThanOrEqualTo(3));
    expect(s.transcript.last.$1, isTrue); // teacher replied
    expect(s.transcript.last.$2, isNotEmpty);

    // Determinism: the same session replayed gives the same transcript.
    final tutor2 = container.read(tutorSessionProvider.notifier)..reset();
    await tutor2.start(TutorMode.teacher);
    await tutor2.send('Hola, quiero practicar.');
    final s2 = container.read(tutorSessionProvider)!;
    expect(s2.transcript.last.$2, s.transcript.last.$2);
  });

  testWidgets('language selector switches curriculum and reseeds learner', (
    tester,
  ) async {
    // Real provider chain: selector → curriculum → learner reseed.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          curriculumProvider.overrideWith((ref) async {
            final code = ref.watch(selectedLanguageProvider);
            return _curriculumFor(code);
          }),
          speechServiceProvider.overrideWithValue(NoopSpeechService()),
          teacherNotebookRepositoryProvider.overrideWithValue(
            InMemoryTeacherNotebookRepository(),
          ),
          experienceRepositoryProvider.overrideWithValue(
            InMemoryExperienceRepository(),
          ),
        ],
        child: const MaterialApp(home: LanguageDashboardScreen()),
      ),
    );
    await _settle(tester);
    expect(find.text('Spanish'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _settle(tester);
    await tester.tap(find.text('English').last);
    await _settle(tester);

    // New curriculum + new demo seed (pro-drop misconception).
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Spanish'), findsNothing);
    // Fresh state: NO leakage from the Spanish session (regression guard —
    // shared repos once contaminated the new language's misconceptions).
    expect(find.textContaining('es:a1'), findsNothing);
    expect(find.textContaining('tener'), findsNothing);
    expect(
      find.textContaining('Wants to clear up: Mandatory subject pronoun'),
      findsOneWidget,
    );

    // Round trip back to Spanish: counts must NOT inflate (2×, not 4×).
    await tester.tap(find.byType(PopupMenuButton<String>));
    await _settle(tester);
    await tester.tap(find.text('Spanish').last);
    await _settle(tester);
    await tester.scrollUntilVisible(find.text("Teacher's Notes"), 150);
    await tester.scrollUntilVisible(find.text('2×').first, 150);
    expect(find.text('2×'), findsWidgets);
    expect(find.text('4×'), findsNothing);
  });

  testWidgets('concept screen shows signals and live-updates on simulate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(curriculum, const LanguageConceptScreen(conceptId: tenerId)),
    );
    await _settle(tester);

    expect(find.text('tener for physical states'), findsOneWidget);
    expect(find.textContaining('tener + noun'), findsWidgets);
    expect(find.text('Adaptive signals'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Misconceptions'), 200);
    // Seeded twice.
    expect(find.textContaining('seen 2×'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Knowledge graph'), 200);
    // Pattern family chips from the graph.
    await tester.scrollUntilVisible(find.text('tener hambre'), 200);

    // Simulate a wrong answer — real engine + detector run, UI updates.
    await tester.scrollUntilVisible(find.text('Wrong'), 200);
    await tester.tap(find.text('Wrong'));
    await _settle(tester);
    expect(find.textContaining('seen 3×'), findsWidgets);
  });

  testWidgets('practice flow: wrong choice surfaces inline teacher note', (
    tester,
  ) async {
    const embarazadaId = 'es:a1:vocabulary:food:restaurant:embarazada';
    await tester.pumpWidget(
      _app(
        curriculum,
        const LanguagePracticeScreen(focus: [embarazadaId]),
      ),
    );
    await _settle(tester);

    // Focused session leads with the embarazada multiple-choice item.
    expect(find.textContaining("What does 'embarazada' mean?"), findsOneWidget);

    // Pick a deliberately wrong option (any option that isn't the answer).
    await tester.tap(find.text('apple').last);
    await _settle(tester);

    expect(find.text('Not quite'), findsOneWidget);
    // The false-friend misconception speaks inline.
    await tester.scrollUntilVisible(find.text('Teacher note'), 200);
    expect(find.textContaining('pregnant'), findsWidgets);

    // Advance: progress header moves to item 2.
    await tester.scrollUntilVisible(find.text('Next'), 200);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.textContaining('Practice 2/'), findsOneWidget);
  });

  testWidgets('unified teacher auto-starts a lesson from real context', (
    tester,
  ) async {
    await tester.pumpWidget(_app(curriculum, const LanguageTutorScreen()));
    await _settle(tester);

    // Phase 18: no mode grid — the Teacher Brain chooses. The header still
    // knows the top misconception, and today's lesson is offered directly.
    expect(find.text('Choose a mode'), findsNothing);
    expect(find.textContaining('First up:'), findsOneWidget);
    expect(find.text("Today's lesson"), findsOneWidget);

    await tester.tap(find.text("Start today's lesson"));
    await _settle(tester);

    // Session starts with assembled context, focused on the demo misconception.
    expect(find.text('Teacher mode'), findsOneWidget);
    expect(find.textContaining('Focus:'), findsOneWidget);
    expect(find.textContaining('misconceptions in context'), findsOneWidget);
    // Demo tutor teaches the tener concept with repair, from graph data.
    expect(find.textContaining('tener'), findsWidgets);
  });

  // Stories + Speaking screens load real assets (rootBundle) and are
  // covered end-to-end by test/language_content_test.dart (parsing,
  // level recommendation, drill generation, scoring, the speaking
  // controller flow with a fake recognizer). They are verified visually
  // on the Android emulator; widget tests over real-async asset I/O are
  // flaky under the shared test binding, so they live at the unit level.

  testWidgets('content studio extracts and reviews from a passage', (
    tester,
  ) async {
    await tester.pumpWidget(_app(curriculum, const LanguageContentScreen()));
    await _settle(tester); // let the overridden curriculum future resolve

    expect(find.text('Content Studio'), findsOneWidget);
    // The sample button ingests without needing keyboard input.
    await tester.tap(find.text('Use sample'));
    await tester.pump();

    // Extracted sections appear with a mapped-to-curriculum summary.
    expect(find.textContaining('candidates'), findsOneWidget);
    expect(find.text('Vocabulary (12)'), findsWidgets);

    // Approve the first candidate → its status flips.
    await tester.tap(find.byIcon(Icons.check_circle).first);
    await tester.pump();
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('onboarding flow steps through language and goals', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LanguageOnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Page 1: welcome.
    expect(find.textContaining('Your personal'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Page 2: pick a language, then continue.
    expect(find.textContaining('like to learn'), findsOneWidget);
    expect(find.text('Spanish'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Page 3: goals, with the final CTA.
    expect(find.text('Set your pace'), findsOneWidget);
    expect(find.text('25 minutes / day'), findsOneWidget);
    expect(find.text('Start learning'), findsOneWidget);
  });

  testWidgets('goals screen sets minutes and target level', (tester) async {
    await tester.pumpWidget(_app(curriculum, const LanguageGoalsScreen()));
    await tester.pump();

    expect(find.text('25 minutes / day'), findsOneWidget);
    // Bump the target level to B1.
    await tester.tap(find.widgetWithText(ChoiceChip, 'B1'));
    await tester.pump();
    expect(
      find.textContaining("aiming for B1"),
      findsOneWidget,
    );
  });
}
