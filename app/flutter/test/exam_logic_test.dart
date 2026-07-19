import 'dart:math';

import 'package:adaptive_language_platform/application/exam_logic.dart';
import 'package:adaptive_language_platform/domain/models.dart';
import 'package:adaptive_language_platform/infrastructure/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMockExam', () {
    test('samples exactly count questions without duplicates', () {
      final exam = buildMockExam(demoQuestions, 10, Random(42));
      expect(exam.length, 10);
      expect(exam.map((q) => q.id).toSet().length, 10);
    });

    test('returns whole pool when count exceeds pool size', () {
      final exam = buildMockExam(demoQuestions, 999, Random(42));
      expect(exam.length, demoQuestions.length);
    });
  });

  group('scoreMockExam', () {
    final questions = demoQuestions.take(4).toList();

    test('all correct passes', () {
      final selections = {for (final q in questions) q.id: q.correctIndex};
      final result = scoreMockExam(questions, selections, 3);
      expect(result.score, 4);
      expect(result.passed, isTrue);
    });

    test('unanswered questions count as wrong', () {
      final selections = {questions.first.id: questions.first.correctIndex};
      final result = scoreMockExam(questions, selections, 3);
      expect(result.score, 1);
      expect(result.passed, isFalse);
    });

    test('exact threshold passes', () {
      final selections = {
        for (final q in questions.take(3)) q.id: q.correctIndex,
      };
      final result = scoreMockExam(questions, selections, 3);
      expect(result.score, 3);
      expect(result.passed, isTrue);
    });
  });

  group('weakTopics', () {
    test('flags low accuracy with enough data, weakest first', () {
      const stats = [
        TopicStats(topicId: 'a', answered: 10, correct: 3), // 30% weak
        TopicStats(topicId: 'b', answered: 10, correct: 9), // 90% fine
        TopicStats(topicId: 'c', answered: 2, correct: 0), // too little data
        TopicStats(topicId: 'd', answered: 10, correct: 5), // 50% weak
      ];
      final weak = weakTopics(stats, minAnswered: 4);
      expect(weak.map((s) => s.topicId).toList(), ['a', 'd']);
    });

    test('empty input yields no weak topics', () {
      expect(weakTopics(const []), isEmpty);
    });
  });

  group('demo data integrity', () {
    test('every question has valid correctIndex and non-empty explanation', () {
      for (final q in demoQuestions) {
        expect(
          q.correctIndex,
          inInclusiveRange(0, q.answers.length - 1),
          reason: q.id,
        );
        expect(q.explanation, isNotEmpty, reason: q.id);
        expect(q.answers.length, inInclusiveRange(2, 6), reason: q.id);
        expect(demoTopics.map((t) => t.id), contains(q.topicId), reason: q.id);
      }
    });

    test('pool is large enough for a mock exam', () {
      expect(
        demoQuestions.length,
        greaterThanOrEqualTo(demoExam.questionCount),
      );
    });
  });
}
