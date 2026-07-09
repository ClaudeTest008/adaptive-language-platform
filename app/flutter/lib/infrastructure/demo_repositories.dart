/// In-memory implementations of the domain repositories ("demo mode").
/// Swapped for Firestore implementations after Epic 4 deploy — the rest of
/// the app depends only on the interfaces.
library;

import 'dart:async';

import '../domain/models.dart';
import '../domain/repositories.dart';
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
    _current = UserProfile(uid: key, displayName: displayName, email: email);
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

class DemoContentRepository implements ContentRepository {
  @override
  Future<Exam> getExam() async => demoExam;

  @override
  Future<List<Topic>> getTopics() async =>
      List.of(demoTopics)..sort((a, b) => a.order.compareTo(b.order));

  @override
  Future<List<Question>> getQuestions({String? topicId}) async =>
      topicId == null
      ? List.of(demoQuestions)
      : demoQuestions.where((q) => q.topicId == topicId).toList();
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
