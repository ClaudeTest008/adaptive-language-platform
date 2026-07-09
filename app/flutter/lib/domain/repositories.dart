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

  /// Published questions only (learner-facing).
  Future<List<Question>> getQuestions({String? topicId});
}

/// Content Studio operations (ADR-0007). Production implementation is
/// admin-gated by custom claims + Firestore rules.
abstract class AdminRepository {
  /// All questions regardless of status.
  Future<List<Question>> getAllQuestions();

  /// Insert or update. Updates bump [Question.version] and stamp
  /// [Question.updatedAt]; published content is never deleted, only
  /// archived via status.
  Future<void> upsertQuestion(Question question);

  Future<void> archiveQuestion(String questionId);
  Future<void> upsertTopic(Topic topic);
  Future<void> updateExam(Exam exam);

  /// Every prior version of a question, newest first (current excluded).
  /// Versions are immutable — questions are never overwritten (ADR-0009).
  Future<List<Question>> getVersionHistory(String questionId);

  /// Restores [version]'s content as a NEW version (history preserved).
  Future<void> rollbackQuestion(String questionId, int version);

  // Bulk operations (Content Studio V2). Each item goes through the same
  // versioned upsert as a single edit.
  Future<void> bulkSetStatus(List<String> questionIds, ContentStatus status);
  Future<void> bulkAddTag(List<String> questionIds, String tag);

  // Import analytics.
  Future<void> recordImportJob(ImportJob job);
  Future<List<ImportJob>> getImportJobs();

  /// Validated batch import (pipeline output only).
  Future<void> importQuestions(List<Question> questions);

  /// Portable content pack (exam + topics + questions) as JSON.
  Future<String> exportContentPack();
  Future<int> importContentPack(String json);
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
