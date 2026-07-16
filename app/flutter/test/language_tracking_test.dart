import 'dart:convert';
import 'dart:io';

import 'package:adaptive_exam_platform/adaptive/engine.dart';
import 'package:adaptive_exam_platform/adaptive/model.dart';
import 'package:adaptive_exam_platform/language/curriculum.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/lesson.dart';
import 'package:adaptive_exam_platform/language/misconceptions.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/signals.dart';
import 'package:flutter_test/flutter_test.dart';

Curriculum _load() => parseCurriculum(
  jsonDecode(File('assets/curriculum/es-for-en.json').readAsStringSync())
      as Map<String, dynamic>,
);

const tenerId = 'es:a1:grammar:verbs:states:tener-states';
const falseFriendId = 'es:a1:vocabulary:food:restaurant:embarazada';
const manzanaId = 'es:a1:vocabulary:food:fruit:manzana';

void main() {
  final curriculum = _load();
  final detector = MisconceptionDetector(
    curriculum.graph,
    nativeLanguage: curriculum.nativeLanguage,
  );
  final at = DateTime(2026, 7, 16);

  group('misconception detection', () {
    test('wrong answer on interference concept detects misconceptions', () {
      final found = detector.detect(
        conceptIds: const [tenerId],
        correct: false,
        at: at,
      );
      // tener-states: 1 interferesWith relation + 1 transfer trap.
      expect(found, hasLength(2));
      final fromRelation = found.firstWhere((m) => m.relationType != null);
      expect(fromRelation.interferenceSource, 'en:be-adjective');
      expect(fromRelation.explanation, contains('tener'));
      expect(fromRelation.nativeLanguage, 'en');
      // Related concepts include the tener phrase family.
      expect(
        fromRelation.relatedConceptIds,
        contains('$tenerId:tener-hambre'),
      );
      final fromTrap = found.firstWhere((m) => m.relationType == null);
      expect(fromTrap.explanation, contains('soy cansado'));
    });

    test('false friend detected on vocabulary error', () {
      final found = detector.detect(
        conceptIds: const [falseFriendId],
        correct: false,
        at: at,
      );
      expect(found, hasLength(1));
      expect(found.single.relationType, LanguageRelationType.falseFriend);
      expect(found.single.explanation, contains('pregnant'));
    });

    test('correct answers and plain mistakes produce nothing', () {
      expect(
        detector.detect(conceptIds: const [tenerId], correct: true, at: at),
        isEmpty,
      );
      // manzana has no authored interference — wrong answer = plain mistake.
      expect(
        detector.detect(conceptIds: const [manzanaId], correct: false, at: at),
        isEmpty,
      );
    });

    test('log merges repeats and bumps occurrences', () {
      var log = const MisconceptionLog();
      log = log.record(
        detector.detect(conceptIds: const [tenerId], correct: false, at: at),
      );
      log = log.record(
        detector.detect(
          conceptIds: const [tenerId],
          correct: false,
          at: at.add(const Duration(minutes: 5)),
        ),
      );
      expect(log.all, hasLength(2)); // still 2 distinct misconceptions
      expect(log.all.first.occurrences, 2); // each seen twice
      expect(log.forConcept(tenerId), hasLength(2));
      expect(log.forConcept(manzanaId), isEmpty);
    });
  });

  group('language signals from answer events', () {
    test('wrong answers raise recall difficulty; correct lower it', () {
      var s = const LanguageConceptSignals();
      final afterWrong = s.afterAnswer(correct: false, responseSeconds: 8);
      expect(afterWrong.recallDifficulty, greaterThan(s.recallDifficulty));
      final afterCorrect = s.afterAnswer(correct: true, responseSeconds: 2);
      expect(afterCorrect.recallDifficulty, lessThan(s.recallDifficulty));
    });

    test('transfer errors tracked separately and drive interference', () {
      var s = const LanguageConceptSignals();
      s = s.afterAnswer(
        correct: false,
        responseSeconds: 8,
        transferError: true,
      );
      expect(s.grammarTransferErrors, 1);
      expect(s.nativeInterference, greaterThan(0));
      final before = s.nativeInterference;
      s = s.afterAnswer(correct: true, responseSeconds: 3);
      expect(s.grammarTransferErrors, 1); // counts never decay
      expect(s.nativeInterference, lessThan(before)); // pressure decays
    });

    test('speed EWMA and usage counting', () {
      var s = const LanguageConceptSignals();
      s = s.afterAnswer(correct: true, responseSeconds: 4);
      expect(s.recallSpeedMs, 4000);
      s = s.afterAnswer(correct: true, responseSeconds: 2);
      expect(s.recallSpeedMs, lessThan(4000));
      expect(s.usageFrequency, 2);
    });

    test('store applies per concept and flags transfer targets only', () {
      var store = const LanguageSignalsStore();
      store = store.afterAnswer(
        conceptIds: const [tenerId, manzanaId],
        correct: false,
        responseSeconds: 6,
        transferConceptIds: const {tenerId},
      );
      expect(store[tenerId].grammarTransferErrors, 1);
      expect(store[manzanaId].grammarTransferErrors, 0);
      expect(store[manzanaId].usageFrequency, 1);
    });
  });

  group('end to end through the unchanged core engine', () {
    test('language answers produce skill mastery + misconceptions + plan', () {
      final engine = LearnerEngine(graph: curriculum.graph.toCoreGraph());
      var model = const LearnerModel();
      var log = const MisconceptionLog();
      var signals = const LanguageSignalsStore();
      var t = DateTime(2026, 7, 15, 9);

      void answer(String id, bool correct, double seconds) {
        final node = curriculum.graph[id]!;
        t = t.add(const Duration(minutes: 3));
        model = engine.applyAnswer(
          model,
          AnswerEvent(
            questionId: 'lx-$id',
            // Leaf-first: AnswerEvent contract is primary concept first.
            conceptIds: node.lineageConceptIds.reversed.toList(),
            correct: correct,
            responseSeconds: seconds,
            difficulty01: 0.5,
            answeredAt: t,
          ),
        );
        final detected = detector.detect(
          conceptIds: [id],
          correct: correct,
          at: t,
        );
        log = log.record(detected);
        signals = signals.afterAnswer(
          conceptIds: [id],
          correct: correct,
          responseSeconds: seconds,
          transferConceptIds: {for (final m in detected) m.conceptId},
        );
      }

      // Vocabulary strong, grammar weak (tener transfer error twice).
      answer(manzanaId, true, 2);
      answer(manzanaId, true, 1.5);
      answer(falseFriendId, true, 3);
      const serEstarId = 'es:a1:grammar:verbs:states:ser-estar';
      answer(serEstarId, true, 5); // give ser-estar mastery to lapse from
      final serEstarBefore = model.concepts[serEstarId]!.mastery;
      answer(tenerId, false, 8);
      answer(tenerId, false, 7);

      // Lapse propagation fires through the language graph: tener wrong
      // reinforces relatedTo neighbor ser-estar downward (regression for
      // the root-first conceptIds bug — propagation keys off .first).
      expect(
        model.concepts[serEstarId]!.mastery,
        lessThan(serEstarBefore),
      );

      final mastery = {
        for (final e in model.concepts.entries) e.key: e.value.mastery,
      };
      final bySkill = skillMastery(mastery, curriculum.graph);
      expect(
        bySkill[LanguageSkill.vocabulary]!,
        greaterThan(bySkill[LanguageSkill.grammar]!),
      );
      expect(
        weakestSkills(mastery, curriculum.graph).first,
        LanguageSkill.grammar,
      );

      // Misconceptions recorded with occurrences.
      expect(log.forConcept(tenerId).first.occurrences, 2);
      expect(signals[tenerId].grammarTransferErrors, 2);

      // Lesson preview leads with misconception repair.
      final blocks = previewDailyLesson(
        conceptMastery: mastery,
        graph: curriculum.graph,
        misconceptions: log,
        availableMinutes: 25,
      );
      expect(blocks.first.kind, LessonBlockKind.repair);
      expect(blocks.first.conceptIds, contains(tenerId));
      expect(blocks.fold(0, (s, b) => s + b.minutes), 25);
      // Repair block carries the pattern family for reteaching.
      expect(blocks.first.conceptIds, contains('$tenerId:tener-hambre'));

      // One repair entry per concept even when a concept carries several
      // misconception log entries (interference relation + transfer trap).
      expect(
        'tener'.allMatches(blocks.first.title).length,
        1,
        reason: blocks.first.title,
      );
      // Concept ids are unique — no double-weighting.
      expect(
        blocks.first.conceptIds.toSet().length,
        blocks.first.conceptIds.length,
      );

      // Tiny budgets must not crash and must respect the budget.
      final tiny = previewDailyLesson(
        conceptMastery: mastery,
        graph: curriculum.graph,
        misconceptions: log,
        availableMinutes: 3,
      );
      expect(tiny.fold(0, (s, b) => s + b.minutes), 3);
      expect(tiny.first.kind, LessonBlockKind.repair);
    });
  });
}
