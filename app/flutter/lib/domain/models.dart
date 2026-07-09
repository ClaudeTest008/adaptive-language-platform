/// Domain entities. Pure Dart — no Flutter, no Firebase (ADR-0001/0002).
library;

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
  });

  final String uid;
  final String displayName;
  final String email;
}

class Exam {
  const Exam({
    required this.id,
    required this.name,
    required this.questionCount,
    required this.passThreshold,
    required this.timeLimitMinutes,
  });

  final String id;
  final String name;

  /// Questions per mock exam.
  final int questionCount;

  /// Minimum correct answers to pass.
  final int passThreshold;
  final int timeLimitMinutes;
}

class Topic {
  const Topic({required this.id, required this.name, required this.order});

  final String id;
  final String name;
  final int order;
}

class Question {
  const Question({
    required this.id,
    required this.examId,
    required this.topicId,
    required this.text,
    required this.answers,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String examId;
  final String topicId;
  final String text;
  final List<String> answers;
  final int correctIndex;
  final String explanation;

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;
}

enum AttemptType { practice, mock, review }

class AttemptAnswer {
  const AttemptAnswer({
    required this.questionId,
    required this.topicId,
    required this.selectedIndex,
    required this.correct,
  });

  final String questionId;
  final String topicId;
  final int selectedIndex;
  final bool correct;
}

class Attempt {
  const Attempt({
    required this.id,
    required this.type,
    required this.examId,
    required this.completedAt,
    required this.durationSeconds,
    required this.score,
    required this.total,
    required this.answers,
    this.passed,
  });

  final String id;
  final AttemptType type;
  final String examId;
  final DateTime completedAt;
  final int durationSeconds;
  final int score;
  final int total;

  /// Mock exams only.
  final bool? passed;
  final List<AttemptAnswer> answers;
}

class TopicStats {
  const TopicStats({
    required this.topicId,
    required this.answered,
    required this.correct,
  });

  final String topicId;
  final int answered;
  final int correct;

  double get accuracy => answered == 0 ? 0 : correct / answered;

  TopicStats record({required bool wasCorrect}) => TopicStats(
    topicId: topicId,
    answered: answered + 1,
    correct: correct + (wasCorrect ? 1 : 0),
  );
}
