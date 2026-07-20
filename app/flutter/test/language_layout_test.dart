import 'dart:convert';
import 'dart:io';

import 'package:adaptive_language_platform/infrastructure/prefs_experience_repository.dart';
import 'package:adaptive_language_platform/language/curriculum.dart';
import 'package:adaptive_language_platform/language/notebook_repository.dart';
import 'package:adaptive_language_platform/language/speech.dart';
import 'package:adaptive_language_platform/language/teacher_memory.dart';
import 'package:adaptive_language_platform/presentation/language_providers.dart';
import 'package:adaptive_language_platform/presentation/screens/language_concept_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/language_content_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/llm_settings_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/whisper_settings_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/language_dashboard_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/language_goals_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/language_onboarding_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/language_practice_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/language_tutor_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/login_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/settings_screen.dart';
import 'package:adaptive_language_platform/presentation/screens/tutor_settings_screen.dart';
import 'package:adaptive_language_platform/presentation/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout-safety matrix.
///
/// A RenderFlex overflow does not throw in release — it paints a yellow bar
/// and is easy to miss on one device in one theme. Under `flutter_test` it is
/// reported as an exception, so pumping every screen across the sizes, text
/// scales and brightnesses we claim to support turns "no overflow" from a
/// manual observation into a reproducible assertion.
const _tenerId = 'es:a1:grammar:verbs:states:tener-states';

Curriculum _curriculum() => parseCurriculum(
      jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// The viewports we claim to support: a small phone, a normal phone, and
/// landscape (where the OS may rotate us regardless of preference).
const _sizes = <String, Size>{
  'small-phone': Size(320, 640),
  'phone': Size(411, 891),
  'landscape': Size(891, 411),
};

/// 1.0 = default, 1.5 = a large accessibility text scale.
const _scales = <double>[1.0, 1.5];

Widget _harness({
  required Curriculum curriculum,
  required Widget home,
  required Brightness brightness,
  required double textScale,
}) {
  return ProviderScope(
    overrides: [
      curriculumProvider.overrideWith((ref) => Future.value(curriculum)),
      speechServiceProvider.overrideWithValue(NoopSpeechService()),
      teacherNotebookRepositoryProvider
          .overrideWithValue(InMemoryTeacherNotebookRepository()),
      experienceRepositoryProvider
          .overrideWithValue(InMemoryExperienceRepository()),
      teacherMemoryRepositoryProvider
          .overrideWithValue(InMemoryTeacherMemoryRepository()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: home,
        ),
      ),
    ),
  );
}

/// Pumps without pumpAndSettle: several screens run indefinite animations
/// (the speaking orb, the streaming caret), which would hang a settle.
Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final curriculum = _curriculum();

  // Screens that can be pumped standalone. The Library/Reader/Speaking
  // screens load assets through rootBundle and are covered by
  // language_content_test + on-device checks instead (documented gotcha).
  final screens = <String, Widget Function()>{
    'dashboard': () => const LanguageDashboardScreen(),
    'tutor': () => const LanguageTutorScreen(),
    'practice': () => const LanguagePracticeScreen(focus: [_tenerId]),
    'concept': () => const LanguageConceptScreen(conceptId: _tenerId),
    'goals': () => const LanguageGoalsScreen(),
    'onboarding': () => const LanguageOnboardingScreen(),
    'login': () => const LoginScreen(),
    'settings': () => const SettingsScreen(),
    'content-studio': () => const LanguageContentScreen(),
    'tutor-settings': () => const TutorSettingsScreen(),
    'whisper-settings': () => const WhisperSettingsScreen(),
    'llm-settings': () => const LlmSettingsScreen(),
  };

  for (final brightness in Brightness.values) {
    for (final scale in _scales) {
      for (final size in _sizes.entries) {
        for (final screen in screens.entries) {
          testWidgets(
            'layout: ${screen.key} · ${brightness.name} · '
            '${size.key} · text×$scale',
            (tester) async {
              tester.view.physicalSize = size.value;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(_harness(
                curriculum: curriculum,
                home: screen.value(),
                brightness: brightness,
                textScale: scale,
              ));
              await _pump(tester);

              // Any RenderFlex overflow (or other layout error) surfaces as a
              // caught exception; fail loudly with the screen/config named.
              expect(
                tester.takeException(),
                isNull,
                reason: '${screen.key} overflowed at ${size.key}, '
                    '${brightness.name}, text scale $scale',
              );
            },
          );
        }
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('design tokens resolve for ${brightness.name}', (tester) async {
      late AppTones tones;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(builder: (context) {
          tones = AppTones.of(context);
          return const SizedBox();
        }),
      ));
      // Text must never match its own background — the class of bug that
      // makes a widget invisible in exactly one theme.
      expect(tones.ink, isNot(tones.canvas));
      expect(tones.ink, isNot(tones.card));
      expect(tones.inkSoft, isNot(tones.canvas));
      expect(tones.onAccent, isNot(tones.accent));
      for (final tint in AppTint.values) {
        expect(tones.onTint(tint), isNot(tones.tint(tint)));
      }
      expect(tones.dark, brightness == Brightness.dark);

      // WCAG contrast: body text on its backgrounds must reach AA (4.5:1);
      // onTint content at least large-text AA (3:1) — tinted cards carry
      // 16px+ semi-bold text.
      double ratio(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(ratio(tones.ink, tones.canvas), greaterThan(4.5));
      expect(ratio(tones.ink, tones.card), greaterThan(4.5));
      expect(ratio(tones.inkSoft, tones.card), greaterThan(4.5));
      expect(ratio(tones.onAccent, tones.accent), greaterThan(4.5));
      for (final tint in AppTint.values) {
        expect(
          ratio(tones.onTint(tint), tones.tint(tint)),
          greaterThan(3.0),
          reason: 'onTint($tint) vs tint($tint) in ${brightness.name}',
        );
      }
    });
  }
}
