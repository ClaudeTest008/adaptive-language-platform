import 'dart:math';

import 'package:adaptive_exam_platform/adaptive/engine.dart';
import 'package:adaptive_exam_platform/adaptive/graph.dart';
import 'package:adaptive_exam_platform/adaptive/model.dart';
import 'package:adaptive_exam_platform/adaptive/scheduler.dart';
import 'package:adaptive_exam_platform/adaptive/selector.dart';
import 'package:adaptive_exam_platform/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 9, 12);

AnswerEvent event(
  String concept, {
  bool correct = true,
  double seconds = 10,
  DateTime? at,
  List<String>? concepts,
}) => AnswerEvent(
  questionId: 'q-$concept',
  conceptIds: concepts ?? [concept],
  correct: correct,
  responseSeconds: seconds,
  difficulty01: 0.5,
  answeredAt: at ?? _now,
);

Question q(String id, String topic, Difficulty d) => Question(
  id: id,
  examId: 'e',
  topicId: topic,
  text: 'Question $id?',
  answers: const ['a', 'b'],
  correctIndex: 0,
  explanation: 'x',
  difficulty: d,
);

void main() {
  const engine = LearnerEngine();

  group('scheduler', () {
    const scheduler = ExpandingIntervalScheduler();

    test('first correct answer schedules ~1 day out', () {
      final s = scheduler.schedule(
        stats: const ConceptStats(conceptId: 'c'),
        correct: true,
        now: _now,
      );
      expect(s.intervalDays, 1);
      expect(s.nextReviewAt, _now.add(const Duration(days: 1)));
    });

    test('correct answers grow the interval up to the cap', () {
      var stats = const ConceptStats(conceptId: 'c');
      for (var i = 0; i < 20; i++) {
        final s = scheduler.schedule(stats: stats, correct: true, now: _now);
        stats = stats.copyWith(intervalDays: s.intervalDays);
      }
      expect(stats.intervalDays, 60); // capped
    });

    test('incorrect answer collapses the interval', () {
      final s = scheduler.schedule(
        stats: const ConceptStats(conceptId: 'c', intervalDays: 30),
        correct: false,
        now: _now,
      );
      expect(s.intervalDays, lessThan(1));
    });
  });

  group('learner model updates', () {
    test('correct answer raises mastery, wrong answer lowers it', () {
      var model = const LearnerModel();
      model = engine.applyAnswer(model, event('signs'));
      final up = model.concepts['signs']!.mastery;
      expect(up, greaterThan(0));
      model = engine.applyAnswer(model, event('signs', correct: false));
      expect(model.concepts['signs']!.mastery, lessThan(up));
      expect(model.totalAnswered, 2);
      expect(model.totalCorrect, 1);
    });

    test('lapse counted only after concept was established', () {
      var model = const LearnerModel();
      model = engine.applyAnswer(model, event('c', correct: false));
      expect(model.concepts['c']!.lapses, 0); // never established
      for (var i = 0; i < 6; i++) {
        model = engine.applyAnswer(model, event('c'));
      }
      expect(model.concepts['c']!.mastery, greaterThan(0.6));
      model = engine.applyAnswer(model, event('c', correct: false));
      expect(model.concepts['c']!.lapses, 1);
    });

    test('all referenced concepts update; streak resets on wrong', () {
      var model = const LearnerModel();
      model = engine.applyAnswer(
        model,
        event('signs', concepts: ['signs', 'tag:priority']),
      );
      expect(model.concepts.keys, containsAll(['signs', 'tag:priority']));
      model = engine.applyAnswer(model, event('signs', correct: false));
      expect(model.concepts['signs']!.streak, 0);
    });

    test('wrong answer propagates reduced penalty to related concepts', () {
      final topics = [
        const Topic(id: 'a', name: 'A', order: 1),
        const Topic(id: 'b', name: 'B', order: 2),
      ];
      final questions = [
        Question(
          id: '1',
          examId: 'e',
          topicId: 'a',
          text: 't',
          answers: const ['x', 'y'],
          correctIndex: 0,
          explanation: 'x',
          tags: const ['shared'],
        ),
        Question(
          id: '2',
          examId: 'e',
          topicId: 'b',
          text: 't2',
          answers: const ['x', 'y'],
          correctIndex: 0,
          explanation: 'x',
          tags: const ['shared'],
        ),
      ];
      final graphEngine = LearnerEngine(
        graph: buildKnowledgeGraph(topics, questions),
      );
      var model = const LearnerModel();
      // Establish concept b, then miss a question in related concept a.
      model = graphEngine.applyAnswer(model, event('b'));
      final bBefore = model.concepts['b']!.mastery;
      model = graphEngine.applyAnswer(model, event('a', correct: false));
      final bAfter = model.concepts['b']!.mastery;
      expect(bAfter, lessThan(bBefore)); // reinforcement propagated
      // Propagation is weaker than a direct wrong answer would be.
      expect(bBefore - bAfter, lessThan(bBefore * 0.3));
    });
  });

  group('confidence', () {
    test('zero without evidence, grows with streak and accuracy', () {
      expect(engine.conceptConfidence(const ConceptStats(conceptId: 'c')), 0);
      var model = const LearnerModel();
      for (var i = 0; i < 8; i++) {
        model = engine.applyAnswer(model, event('c', seconds: 8));
      }
      expect(engine.conceptConfidence(model.concepts['c']!), greaterThan(0.7));
    });

    test('slow responses and lapses reduce confidence', () {
      var fast = const LearnerModel();
      var slow = const LearnerModel();
      for (var i = 0; i < 6; i++) {
        fast = engine.applyAnswer(fast, event('c', seconds: 5));
        slow = engine.applyAnswer(slow, event('c', seconds: 60));
      }
      expect(
        engine.conceptConfidence(slow.concepts['c']!),
        lessThan(engine.conceptConfidence(fast.concepts['c']!)),
      );
    });
  });

  group('knowledge graph', () {
    test('builds topic, subtopic and tag nodes with relations', () {
      final topics = [const Topic(id: 't1', name: 'T1', order: 1)];
      final questions = [
        Question(
          id: '1',
          examId: 'e',
          topicId: 't1',
          text: 'x',
          answers: const ['a', 'b'],
          correctIndex: 0,
          explanation: 'x',
          subtopic: 'lights',
          tags: const ['night'],
        ),
      ];
      final graph = buildKnowledgeGraph(topics, questions);
      expect(graph['t1'], isNotNull);
      expect(graph['sub:t1:lights']!.prerequisites, ['t1']);
      expect(graph['tag:night']!.related, contains('t1'));
      expect(graph['t1']!.followUps, contains('sub:t1:lights'));
    });

    test('conceptsForQuestion always leads with the topic', () {
      final concepts = conceptsForQuestion(
        Question(
          id: '1',
          examId: 'e',
          topicId: 'signs',
          text: 'x',
          answers: const ['a', 'b'],
          correctIndex: 0,
          explanation: 'x',
          subtopic: 'octagons',
          tags: const ['basics'],
        ),
      );
      expect(concepts, ['signs', 'sub:signs:octagons', 'tag:basics']);
    });
  });

  group('readiness', () {
    const topicIds = ['a', 'b', 'c', 'd'];

    test('empty model: zero readiness, low pass probability', () {
      final r = engine.readiness(
        const LearnerModel(),
        allTopicIds: topicIds,
        passRatio: 0.8,
        now: _now,
      );
      expect(r.readiness, 0);
      expect(r.knowledgeCoverage, 0);
      expect(r.passProbability, lessThan(0.01));
    });

    test('strong model: high readiness and pass probability', () {
      var model = const LearnerModel();
      for (final t in topicIds) {
        for (var i = 0; i < 8; i++) {
          model = engine.applyAnswer(model, event(t, seconds: 8));
        }
      }
      model = engine.recordMockExam(model, 0.9);
      final r = engine.readiness(
        model,
        allTopicIds: topicIds,
        passRatio: 0.8,
        now: _now,
      );
      expect(r.knowledgeCoverage, 1);
      expect(r.readiness, greaterThan(0.8));
      expect(r.passProbability, greaterThan(0.5));
      expect(r.topicReadiness['a'], greaterThan(0.7));
    });

    test('overdue reviews lower retention', () {
      var model = const LearnerModel();
      final past = _now.subtract(const Duration(days: 30));
      model = engine.applyAnswer(model, event('a', at: past));
      final r = engine.readiness(
        model,
        allTopicIds: const ['a'],
        passRatio: 0.8,
        now: _now,
      );
      expect(r.retentionScore, 0); // the only scheduled review is overdue
    });
  });

  group('study plan', () {
    test('prioritizes due reviews over weak over unseen', () {
      var model = const LearnerModel();
      // 'due': answered long ago → overdue review.
      model = engine.applyAnswer(
        model,
        event('due', at: _now.subtract(const Duration(days: 10))),
      );
      // 'weak': repeated recent misses.
      for (var i = 0; i < 4; i++) {
        model = engine.applyAnswer(model, event('weak', correct: false));
      }
      final plan = engine.studyPlan(
        model,
        allTopicIds: const ['due', 'weak', 'unseen'],
        now: _now,
      );
      expect(plan.items.first.conceptId, 'due');
      expect(plan.items[1].conceptId, 'weak');
      expect(plan.items[2].conceptId, 'unseen');
      expect(plan.dueReviewCount, 1);
      expect(plan.estimatedMinutes, greaterThan(0));
    });
  });

  group('learning DNA', () {
    test('needs minimum evidence', () {
      expect(engine.learningDna(const LearnerModel()), isEmpty);
    });

    test('fast accurate learner gets fastResponder + highConfidence', () {
      var model = const LearnerModel();
      for (var i = 0; i < 12; i++) {
        model = engine.applyAnswer(model, event('c', seconds: 4));
      }
      final dna = engine.learningDna(model);
      expect(dna, contains(LearningTrait.fastResponder));
      expect(dna, contains(LearningTrait.highConfidence));
    });

    test('slow but accurate detected', () {
      var model = const LearnerModel();
      for (var i = 0; i < 12; i++) {
        model = engine.applyAnswer(model, event('c', seconds: 30));
      }
      expect(
        engine.learningDna(model),
        contains(LearningTrait.slowButAccurate),
      );
    });
  });

  group('adaptive selector', () {
    final selector = AdaptiveQuestionSelector(
      engine: engine,
      random: Random(7),
    );
    final pool = [
      q('due1', 'due', Difficulty.medium),
      q('weak1', 'weak', Difficulty.easy),
      q('new1', 'unseen', Difficulty.medium),
      q('strong1', 'strong', Difficulty.medium),
    ];

    test('due > weak > unseen > consolidation ordering', () {
      var model = const LearnerModel();
      model = engine.applyAnswer(
        model,
        event('due', at: _now.subtract(const Duration(days: 10))),
      );
      for (var i = 0; i < 4; i++) {
        model = engine.applyAnswer(model, event('weak', correct: false));
      }
      for (var i = 0; i < 8; i++) {
        model = engine.applyAnswer(model, event('strong', seconds: 6));
      }
      final selected = selector.select(
        pool: pool,
        model: model,
        count: 4,
        now: _now,
      );
      expect(selected.map((x) => x.topicId).toList(), [
        'due',
        'weak',
        'unseen',
        'strong',
      ]);
    });

    test('respects requested count', () {
      final selected = selector.select(
        pool: pool,
        model: const LearnerModel(),
        count: 2,
        now: _now,
      );
      expect(selected, hasLength(2));
    });
  });
}
