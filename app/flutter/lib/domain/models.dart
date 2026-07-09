/// Domain entities. Pure Dart — no Flutter, no Firebase (ADR-0001/0002).
library;

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.isAdmin = false,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool isAdmin;
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

  Exam copyWith({
    String? name,
    int? questionCount,
    int? passThreshold,
    int? timeLimitMinutes,
  }) => Exam(
    id: id,
    name: name ?? this.name,
    questionCount: questionCount ?? this.questionCount,
    passThreshold: passThreshold ?? this.passThreshold,
    timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
  );
}

class Topic {
  const Topic({required this.id, required this.name, required this.order});

  final String id;
  final String name;
  final int order;
}

enum Difficulty { easy, medium, hard }

enum ContentStatus { draft, published, archived }

class Question {
  const Question({
    required this.id,
    required this.examId,
    required this.topicId,
    required this.text,
    required this.answers,
    required this.correctIndex,
    required this.explanation,
    this.difficulty = Difficulty.medium,
    this.status = ContentStatus.published,
    this.version = 1,
    this.tags = const [],
    this.subtopic,
    this.learningObjective,
    this.references = const [],
    this.author,
    this.updatedAt,
  });

  final String id;
  final String examId;
  final String topicId;
  final String text;
  final List<String> answers;
  final int correctIndex;
  final String explanation;
  final Difficulty difficulty;
  final ContentStatus status;
  final int version;
  final List<String> tags;
  final String? subtopic;
  final String? learningObjective;
  final List<String> references;
  final String? author;
  final DateTime? updatedAt;

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;

  Question copyWith({
    String? topicId,
    String? text,
    List<String>? answers,
    int? correctIndex,
    String? explanation,
    Difficulty? difficulty,
    ContentStatus? status,
    int? version,
    List<String>? tags,
    String? subtopic,
    String? learningObjective,
    List<String>? references,
    String? author,
    DateTime? updatedAt,
  }) => Question(
    id: id,
    examId: examId,
    topicId: topicId ?? this.topicId,
    text: text ?? this.text,
    answers: answers ?? this.answers,
    correctIndex: correctIndex ?? this.correctIndex,
    explanation: explanation ?? this.explanation,
    difficulty: difficulty ?? this.difficulty,
    status: status ?? this.status,
    version: version ?? this.version,
    tags: tags ?? this.tags,
    subtopic: subtopic ?? this.subtopic,
    learningObjective: learningObjective ?? this.learningObjective,
    references: references ?? this.references,
    author: author ?? this.author,
    updatedAt: updatedAt ?? this.updatedAt,
  );
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
