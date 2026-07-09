/// In-memory implementations of the domain repositories ("demo mode").
/// Swapped for Firestore implementations after Epic 4 deploy — the rest of
/// the app depends only on the interfaces.
library;

import 'dart:async';

import '../domain/models.dart';
import '../domain/repositories.dart';
import 'content_pack.dart';
import 'demo_data.dart';

class DemoAuthRepository implements AuthRepository {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _current;
  final _registered = <String, ({String password, String displayName})>{};

  @override
  Stream<UserProfile?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  UserProfile? get currentUser => _current;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final account = _registered[email.toLowerCase()];
    if (account == null || account.password != password) {
      throw Exception('Invalid email or password.');
    }
    _current = UserProfile(
      uid: email.toLowerCase(),
      displayName: account.displayName,
      email: email,
      isAdmin: true, // demo mode: every user is admin (ADR-0007)
    );
    _controller.add(_current);
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters.');
    }
    final key = email.toLowerCase();
    if (_registered.containsKey(key)) {
      throw Exception('An account already exists for this email.');
    }
    _registered[key] = (password: password, displayName: displayName);
    _current = UserProfile(
      uid: key,
      displayName: displayName,
      email: email,
      isAdmin: true, // demo mode: every user is admin (ADR-0007)
    );
    _controller.add(_current);
  }

  @override
  Future<void> resetPassword(String email) async {
    if (!_registered.containsKey(email.toLowerCase())) {
      throw Exception('No account found for this email.');
    }
    // Demo mode: real implementation sends a Firebase reset email.
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    if (_current != null) _registered.remove(_current!.uid);
    _current = null;
    _controller.add(null);
  }
}

/// Mutable in-memory content store, seeded from demo data. Serves both the
/// learner-facing [ContentRepository] (published only) and the Content
/// Studio [AdminRepository].
class DemoContentRepository implements ContentRepository, AdminRepository {
  Exam _exam = demoExam;
  final List<Topic> _topics = List.of(demoTopics);
  final Map<String, Question> _questions = {
    for (final q in demoQuestions) q.id: q,
  };

  /// Immutable prior versions per question, oldest first. Mirrors the
  /// Firestore `questionVersions/{id}/versions` subcollection.
  final Map<String, List<Question>> _versions = {};
  final List<ImportJob> _importJobs = [];

  // ---- ContentRepository (learner) ----

  @override
  Future<Exam> getExam() async => _exam;

  @override
  Future<List<Topic>> getTopics() async =>
      List.of(_topics)..sort((a, b) => a.order.compareTo(b.order));

  @override
  Future<List<Question>> getQuestions({String? topicId}) async => _questions
      .values
      .where(
        (q) =>
            q.status == ContentStatus.published &&
            (topicId == null || q.topicId == topicId),
      )
      .toList();

  // ---- AdminRepository (Content Studio) ----

  @override
  Future<List<Question>> getAllQuestions() async => List.of(_questions.values);

  @override
  Future<void> upsertQuestion(Question question) async {
    final existing = _questions[question.id];
    if (existing != null) {
      _versions.putIfAbsent(question.id, () => []).add(existing);
    }
    _questions[question.id] = question.copyWith(
      version: existing == null ? question.version : existing.version + 1,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Question>> getVersionHistory(String questionId) async =>
      List.of((_versions[questionId] ?? const []).reversed);

  @override
  Future<void> rollbackQuestion(String questionId, int version) async {
    final target = (_versions[questionId] ?? const [])
        .where((q) => q.version == version)
        .firstOrNull;
    if (target == null) {
      throw StateError('Version $version not found for $questionId.');
    }
    // Restore as a NEW version — history is never rewritten.
    await upsertQuestion(target);
  }

  @override
  Future<void> bulkSetStatus(
    List<String> questionIds,
    ContentStatus status,
  ) async {
    for (final id in questionIds) {
      final q = _questions[id];
      if (q != null && q.status != status) {
        await upsertQuestion(q.copyWith(status: status));
      }
    }
  }

  @override
  Future<void> bulkAddTag(List<String> questionIds, String tag) async {
    for (final id in questionIds) {
      final q = _questions[id];
      if (q != null && !q.tags.contains(tag)) {
        await upsertQuestion(q.copyWith(tags: [...q.tags, tag]));
      }
    }
  }

  @override
  Future<void> recordImportJob(ImportJob job) async => _importJobs.add(job);

  @override
  Future<List<ImportJob>> getImportJobs() async =>
      List.of(_importJobs.reversed);

  final Map<String, QuestionCandidate> _candidates = {};

  @override
  Future<void> saveCandidates(List<QuestionCandidate> candidates) async {
    for (final c in candidates) {
      _candidates[c.id] = c;
    }
  }

  @override
  Future<List<QuestionCandidate>> getCandidates() async =>
      List.of(_candidates.values);

  @override
  Future<void> removeCandidates(List<String> candidateIds) async {
    for (final id in candidateIds) {
      _candidates.remove(id);
    }
  }

  @override
  Future<void> archiveQuestion(String questionId) async {
    final q = _questions[questionId];
    if (q != null) {
      await upsertQuestion(q.copyWith(status: ContentStatus.archived));
    }
  }

  @override
  Future<void> upsertTopic(Topic topic) async {
    _topics
      ..removeWhere((t) => t.id == topic.id)
      ..add(topic);
  }

  @override
  Future<void> updateExam(Exam exam) async => _exam = exam;

  @override
  Future<void> importQuestions(List<Question> questions) async {
    for (final q in questions) {
      await upsertQuestion(q);
    }
  }

  @override
  Future<String> exportContentPack() async => encodeContentPack(
    exam: _exam,
    topics: _topics,
    questions: _questions.values.toList(),
  );

  @override
  Future<int> importContentPack(String json) async {
    final pack = decodeContentPack(json);
    _exam = pack.exam;
    _topics
      ..clear()
      ..addAll(pack.topics);
    for (final q in pack.questions) {
      _questions[q.id] = q;
    }
    return pack.questions.length;
  }
}

class DemoStudyRepository implements StudyRepository {
  final _attempts = <Attempt>[];
  final _bookmarks = <String>{};
  final _incorrect = <String>{};
  final _topicStats = <String, TopicStats>{};

  @override
  Future<void> recordAnswer(AttemptAnswer answer) async {
    final stats =
        _topicStats[answer.topicId] ??
        TopicStats(topicId: answer.topicId, answered: 0, correct: 0);
    _topicStats[answer.topicId] = stats.record(wasCorrect: answer.correct);
    if (answer.correct) {
      _incorrect.remove(answer.questionId);
    } else {
      _incorrect.add(answer.questionId);
    }
  }

  @override
  Future<void> saveAttempt(Attempt attempt) async => _attempts.add(attempt);

  @override
  Future<List<Attempt>> getAttempts() async => List.of(_attempts.reversed);

  @override
  Future<Set<String>> getBookmarkedQuestionIds() async => Set.of(_bookmarks);

  @override
  Future<void> toggleBookmark(String questionId) async {
    _bookmarks.contains(questionId)
        ? _bookmarks.remove(questionId)
        : _bookmarks.add(questionId);
  }

  @override
  Future<Set<String>> getIncorrectQuestionIds() async => Set.of(_incorrect);

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => Map.of(_topicStats);

  @override
  Future<void> clearAll() async {
    _attempts.clear();
    _bookmarks.clear();
    _incorrect.clear();
    _topicStats.clear();
  }
}
