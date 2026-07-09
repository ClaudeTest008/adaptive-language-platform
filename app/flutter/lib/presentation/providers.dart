/// Riverpod wiring: repositories bound to demo implementations, app-level
/// state, and session controllers (practice + mock exam).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../application/exam_logic.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import '../infrastructure/demo_repositories.dart';

// ---------- repositories (swap point for Firestore implementations) ----------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DemoAuthRepository(),
);

/// Single store serves both learner content and Content Studio admin ops.
final _contentStoreProvider = Provider<DemoContentRepository>(
  (ref) => DemoContentRepository(),
);
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ref.watch(_contentStoreProvider),
);
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => ref.watch(_contentStoreProvider),
);
final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => DemoStudyRepository(),
);

// ---------- app state ----------

final authStateProvider = StreamProvider<UserProfile?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Bumped after any Content Studio write so learner + admin views refresh.
final contentVersionProvider = StateProvider<int>((ref) => 0);

final examProvider = FutureProvider((ref) {
  ref.watch(contentVersionProvider);
  return ref.watch(contentRepositoryProvider).getExam();
});
final topicsProvider = FutureProvider((ref) {
  ref.watch(contentVersionProvider);
  return ref.watch(contentRepositoryProvider).getTopics();
});
final questionsProvider = FutureProvider((ref) {
  ref.watch(contentVersionProvider);
  return ref.watch(contentRepositoryProvider).getQuestions();
});

/// Content Studio: all questions regardless of status.
final allQuestionsProvider = FutureProvider((ref) {
  ref.watch(contentVersionProvider);
  return ref.watch(adminRepositoryProvider).getAllQuestions();
});

/// Bumped after any study write so dashboard/bookmark/review views refresh.
final studyVersionProvider = StateProvider<int>((ref) => 0);

final topicStatsProvider = FutureProvider((ref) {
  ref.watch(studyVersionProvider);
  return ref.watch(studyRepositoryProvider).getTopicStats();
});
final attemptsProvider = FutureProvider((ref) {
  ref.watch(studyVersionProvider);
  return ref.watch(studyRepositoryProvider).getAttempts();
});
final bookmarksProvider = FutureProvider((ref) {
  ref.watch(studyVersionProvider);
  return ref.watch(studyRepositoryProvider).getBookmarkedQuestionIds();
});
final incorrectIdsProvider = FutureProvider((ref) {
  ref.watch(studyVersionProvider);
  return ref.watch(studyRepositoryProvider).getIncorrectQuestionIds();
});

// ---------- practice session ----------

class PracticeState {
  const PracticeState({
    required this.questions,
    required this.index,
    required this.correctCount,
    required this.startedAt,
    this.selectedIndex,
    this.finished = false,
  });

  final List<Question> questions;
  final int index;
  final int correctCount;
  final DateTime startedAt;

  /// Non-null once the current question is answered (feedback shown).
  final int? selectedIndex;
  final bool finished;

  Question get current => questions[index];
  bool get answered => selectedIndex != null;

  PracticeState copyWith({
    int? index,
    int? correctCount,
    int? selectedIndex,
    bool clearSelection = false,
    bool? finished,
  }) => PracticeState(
    questions: questions,
    index: index ?? this.index,
    correctCount: correctCount ?? this.correctCount,
    startedAt: startedAt,
    selectedIndex: clearSelection
        ? null
        : (selectedIndex ?? this.selectedIndex),
    finished: finished ?? this.finished,
  );
}

class PracticeController extends Notifier<PracticeState?> {
  @override
  PracticeState? build() => null;

  void start(List<Question> questions) {
    state = PracticeState(
      questions: questions,
      index: 0,
      correctCount: 0,
      startedAt: DateTime.now(),
    );
  }

  Future<void> answer(int selectedIndex) async {
    final s = state;
    if (s == null || s.answered) return;
    final correct = s.current.isCorrect(selectedIndex);
    state = s.copyWith(
      selectedIndex: selectedIndex,
      correctCount: s.correctCount + (correct ? 1 : 0),
    );
    await ref
        .read(studyRepositoryProvider)
        .recordAnswer(
          AttemptAnswer(
            questionId: s.current.id,
            topicId: s.current.topicId,
            selectedIndex: selectedIndex,
            correct: correct,
          ),
        );
    ref.read(studyVersionProvider.notifier).state++;
  }

  /// Advances to the next question; on the last question finishes the
  /// session and persists the attempt.
  Future<void> next({required AttemptType type}) async {
    final s = state;
    if (s == null || !s.answered) return;
    if (s.index + 1 < s.questions.length) {
      state = s.copyWith(index: s.index + 1, clearSelection: true);
      return;
    }
    final exam = await ref.read(contentRepositoryProvider).getExam();
    await ref
        .read(studyRepositoryProvider)
        .saveAttempt(
          Attempt(
            id: 'a${DateTime.now().microsecondsSinceEpoch}',
            type: type,
            examId: exam.id,
            completedAt: DateTime.now(),
            durationSeconds: DateTime.now().difference(s.startedAt).inSeconds,
            score: s.correctCount,
            total: s.questions.length,
            answers: const [],
          ),
        );
    ref.read(studyVersionProvider.notifier).state++;
    state = s.copyWith(finished: true);
  }

  void reset() => state = null;
}

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState?>(
      PracticeController.new,
    );

// ---------- mock exam session ----------

class MockExamState {
  const MockExamState({
    required this.questions,
    required this.selections,
    required this.remainingSeconds,
    required this.startedAt,
    this.result,
  });

  final List<Question> questions;
  final Map<String, int> selections;
  final int remainingSeconds;
  final DateTime startedAt;
  final MockResult? result;

  bool get finished => result != null;
}

class MockExamController extends Notifier<MockExamState?> {
  Timer? _timer;

  @override
  MockExamState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  Future<void> start() async {
    final content = ref.read(contentRepositoryProvider);
    final exam = await content.getExam();
    final pool = await content.getQuestions();
    state = MockExamState(
      questions: buildMockExam(pool, exam.questionCount, Random()),
      selections: const {},
      remainingSeconds: exam.timeLimitMinutes * 60,
      startedAt: DateTime.now(),
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null || s.finished) {
      _timer?.cancel();
      return;
    }
    if (s.remainingSeconds <= 1) {
      submit(); // auto-submit at zero (FR-4.2)
    } else {
      state = MockExamState(
        questions: s.questions,
        selections: s.selections,
        remainingSeconds: s.remainingSeconds - 1,
        startedAt: s.startedAt,
      );
    }
  }

  void select(String questionId, int answerIndex) {
    final s = state;
    if (s == null || s.finished) return;
    state = MockExamState(
      questions: s.questions,
      selections: {...s.selections, questionId: answerIndex},
      remainingSeconds: s.remainingSeconds,
      startedAt: s.startedAt,
    );
  }

  Future<void> submit() async {
    final s = state;
    if (s == null || s.finished) return;
    _timer?.cancel();
    final exam = await ref.read(contentRepositoryProvider).getExam();
    final result = scoreMockExam(s.questions, s.selections, exam.passThreshold);

    final study = ref.read(studyRepositoryProvider);
    final answers = <AttemptAnswer>[];
    for (final q in s.questions) {
      final selected = s.selections[q.id];
      final answer = AttemptAnswer(
        questionId: q.id,
        topicId: q.topicId,
        selectedIndex: selected ?? -1,
        correct: selected != null && q.isCorrect(selected),
      );
      answers.add(answer);
      await study.recordAnswer(answer);
    }
    await study.saveAttempt(
      Attempt(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        type: AttemptType.mock,
        examId: exam.id,
        completedAt: DateTime.now(),
        durationSeconds: DateTime.now().difference(s.startedAt).inSeconds,
        score: result.score,
        total: result.total,
        passed: result.passed,
        answers: answers,
      ),
    );
    ref.read(studyVersionProvider.notifier).state++;

    state = MockExamState(
      questions: s.questions,
      selections: s.selections,
      remainingSeconds: s.remainingSeconds,
      startedAt: s.startedAt,
      result: result,
    );
  }

  void reset() {
    _timer?.cancel();
    state = null;
  }
}

final mockExamControllerProvider =
    NotifierProvider<MockExamController, MockExamState?>(
      MockExamController.new,
    );
