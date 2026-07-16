import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/presentation/language_providers.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_concept_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_dashboard_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_practice_screen.dart';
import 'package:adaptive_exam_platform/presentation/screens/language_tutor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const tenerId = 'es:a1:grammar:verbs:states:tener-states';

Curriculum _curriculum() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

Widget _app(Curriculum c, Widget home) => ProviderScope(
  overrides: [curriculumProvider.overrideWith((ref) => Future.value(c))],
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

    // Independent per-skill mastery bars.
    expect(find.text('Skill mastery'), findsOneWidget);
    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);

    // Teacher notes: tener misconception with explanation + occurrences.
    await tester.scrollUntilVisible(find.text('Teacher notes'), 200);
    expect(find.text('2×'), findsWidgets);
    expect(
      find.textContaining('tener', findRichText: true),
      findsWidgets,
    );

    // Lesson preview leads with misconception repair.
    await tester.scrollUntilVisible(find.text("Today's lesson"), 200);
    await tester.pump();
    expect(find.textContaining('Repair:'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('25 minutes today'), 200);
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

  testWidgets('tutor: mode selector starts a teacher session with real '
      'context', (tester) async {
    await tester.pumpWidget(_app(curriculum, const LanguageTutorScreen()));
    await _settle(tester);

    // All six modes offered.
    for (final title in [
      'Teacher', 'Conversation', 'Coach', 'Socratic', 'Grammar', 'Immersion',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // Context header knows the top misconception from the demo seed.
    expect(find.textContaining('First up:'), findsOneWidget);

    await tester.tap(find.text('Teacher'));
    await _settle(tester);

    // Session chips show assembled context.
    expect(find.text('Teacher mode'), findsOneWidget);
    expect(find.textContaining('Focus:'), findsOneWidget);
    expect(find.textContaining('misconceptions in context'), findsOneWidget);
    // Demo tutor teaches the tener concept with repair, from graph data.
    expect(find.textContaining('tener'), findsWidgets);
  });
}
