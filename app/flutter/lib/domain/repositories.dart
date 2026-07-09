/// Repository interfaces. Infrastructure provides implementations
/// (demo in-memory now; Firestore when Epic 4 deploy completes).
library;

import 'models.dart';

abstract class AuthRepository {
  Stream<UserProfile?> authStateChanges();
  UserProfile? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<void> deleteAccount();
}

abstract class ContentRepository {
  Future<Exam> getExam();
  Future<List<Topic>> getTopics();
  Future<List<Question>> getQuestions({String? topicId});
}

abstract class StudyRepository {
  /// Records a single answer event: updates topic stats and the
  /// review-incorrect pool (wrong answers enter it, correct ones leave it).
  Future<void> recordAnswer(AttemptAnswer answer);

  Future<void> saveAttempt(Attempt attempt);
  Future<List<Attempt>> getAttempts();

  Future<Set<String>> getBookmarkedQuestionIds();
  Future<void> toggleBookmark(String questionId);

  Future<Set<String>> getIncorrectQuestionIds();

  Future<Map<String, TopicStats>> getTopicStats();

  Future<void> clearAll();
}
