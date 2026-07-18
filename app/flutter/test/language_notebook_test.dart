import 'package:adaptive_exam_platform/infrastructure/prefs_notebook_repository.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/misconceptions.dart';
import 'package:adaptive_exam_platform/language/notebook.dart';
import 'package:adaptive_exam_platform/language/notebook_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Misconception _misc(String conceptId, {int occurrences = 1}) => Misconception(
  id: '$conceptId|en:transfer',
  conceptId: conceptId,
  nativeLanguage: 'en',
  interferenceSource: 'en:be-adjective',
  pattern: 'tener + noun',
  explanation: 'English "to be" maps to Spanish "tener" here.',
  occurrences: occurrences,
  lastSeen: DateTime(2026, 7, 18),
);

void main() {
  group('buildTeacherNotebook', () {
    test('brand-new learner gets an honest starter note, no fabrication', () {
      final nb = buildTeacherNotebook(
        mastery: const {},
        misconceptions: const [],
        accuracy: 0,
        totalAnswered: 0,
        baseLevel: 'A1',
      );
      expect(nb.observations, hasLength(1));
      expect(nb.observations.single.text, contains('getting started'));
      expect(nb.cefrEstimate, 'A1');
    });

    test('grammar mistake surfaces first, named from the concept map', () {
      final nb = buildTeacherNotebook(
        mastery: const {LanguageSkill.vocabulary: 0.5},
        misconceptions: [_misc('es:a1:tener', occurrences: 3)],
        accuracy: 0.6,
        totalAnswered: 20,
        baseLevel: 'A1',
        conceptNames: const {'es:a1:tener': 'tener for states'},
      );
      final first = nb.observations.first;
      expect(first.category, ObservationCategory.grammar);
      expect(first.text, contains('tener for states'));
      expect(first.text, contains('3×'));
    });

    test('vocabulary and level notes reflect real numbers', () {
      final nb = buildTeacherNotebook(
        mastery: const {
          LanguageSkill.vocabulary: 0.42,
          LanguageSkill.grammar: 0.3,
        },
        misconceptions: const [],
        accuracy: 0.5,
        totalAnswered: 30,
        baseLevel: 'A1',
      );
      expect(
        nb.observations.any((o) => o.text.contains('42% of A1 vocabulary')),
        isTrue,
      );
    });

    test('trend note reads "up" when average mastery rose since last time', () {
      final previous = NotebookSnapshot(
        day: '2026-07-17',
        mastery: const {LanguageSkill.grammar: 0.2},
        accuracy: 0.4,
        misconceptionTotal: 2,
      );
      final nb = buildTeacherNotebook(
        mastery: const {LanguageSkill.grammar: 0.6},
        misconceptions: const [],
        accuracy: 0.7,
        totalAnswered: 40,
        baseLevel: 'A1',
        previous: previous,
      );
      expect(
        nb.observations.any(
          (o) =>
              o.category == ObservationCategory.trend &&
              o.text.contains('up'),
        ),
        isTrue,
      );
    });

    test('plan note carries the next concept and is a plan kind', () {
      final nb = buildTeacherNotebook(
        mastery: const {LanguageSkill.grammar: 0.5},
        misconceptions: const [],
        accuracy: 0.6,
        totalAnswered: 25,
        baseLevel: 'A1',
        nextConceptName: 'imperfect tense',
      );
      final plan = nb.observations.firstWhere(
        (o) => o.kind == ObservationKind.plan,
      );
      expect(plan.text, contains('Imperfect tense'));
    });
  });

  group('estimateCefr', () {
    test('bands rise with average mastery', () {
      expect(estimateCefr(baseLevel: 'A1', avgMastery: 0.1), 'A1');
      expect(estimateCefr(baseLevel: 'A1', avgMastery: 0.7), 'A1+');
      expect(estimateCefr(baseLevel: 'A1', avgMastery: 0.9), 'A2');
    });
  });

  group('mergeSnapshot', () {
    NotebookSnapshot snap(String day) => NotebookSnapshot(
      day: day,
      mastery: const {LanguageSkill.grammar: 0.5},
      accuracy: 0.5,
      misconceptionTotal: 0,
    );

    test('replaces same-day entry and stays sorted', () {
      var history = <NotebookSnapshot>[];
      history = mergeSnapshot(history, snap('2026-07-17'));
      history = mergeSnapshot(history, snap('2026-07-18'));
      history = mergeSnapshot(history, snap('2026-07-18')); // same day again
      expect(history.map((s) => s.day), ['2026-07-17', '2026-07-18']);
    });

    test('caps at notebookHistoryCap, keeping the most recent days', () {
      var history = <NotebookSnapshot>[];
      for (var i = 0; i < notebookHistoryCap + 5; i++) {
        history = mergeSnapshot(
          history,
          snap('2026-${(i % 12 + 1).toString().padLeft(2, '0')}-'
              '${(i % 28 + 1).toString().padLeft(2, '0')}'),
        );
      }
      expect(history.length, lessThanOrEqualTo(notebookHistoryCap));
    });
  });

  test('NotebookSnapshot JSON round-trips', () {
    final s = NotebookSnapshot(
      day: '2026-07-18',
      mastery: const {
        LanguageSkill.grammar: 0.6,
        LanguageSkill.speaking: 0.3,
      },
      accuracy: 0.55,
      misconceptionTotal: 4,
    );
    final back = NotebookSnapshot.fromJson(s.toJson());
    expect(back.day, s.day);
    expect(back.accuracy, s.accuracy);
    expect(back.misconceptionTotal, 4);
    expect(back.mastery[LanguageSkill.grammar], 0.6);
    expect(back.mastery[LanguageSkill.speaking], 0.3);
  });

  test('InMemory repository persists and merges by day', () async {
    final repo = InMemoryTeacherNotebookRepository();
    await repo.saveSnapshot(
      NotebookSnapshot(
        day: '2026-07-18',
        mastery: const {LanguageSkill.grammar: 0.5},
        accuracy: 0.5,
        misconceptionTotal: 1,
      ),
    );
    final history = await repo.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.day, '2026-07-18');
  });

  test('Prefs repository round-trips through shared_preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrefsTeacherNotebookRepository();
    await repo.saveSnapshot(
      NotebookSnapshot(
        day: '2026-07-18',
        mastery: const {LanguageSkill.grammar: 0.7},
        accuracy: 0.6,
        misconceptionTotal: 2,
      ),
    );
    final reloaded = await PrefsTeacherNotebookRepository().loadHistory();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.mastery[LanguageSkill.grammar], 0.7);
    expect(reloaded.single.misconceptionTotal, 2);
  });
}
