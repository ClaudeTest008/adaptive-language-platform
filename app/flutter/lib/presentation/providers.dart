/// Riverpod wiring: repositories bound to demo implementations, app-level
/// state, and session controllers (practice + mock exam).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../adaptive/engine.dart';
import '../adaptive/graph.dart';
import '../adaptive/model.dart' as adaptive;
import '../adaptive/repository.dart';
import '../adaptive/selector.dart';
import '../application/exam_logic.dart';
import '../domain/ai_services.dart';
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

/// Content Studio: import job history (newest first).
final importJobsProvider = FutureProvider((ref) {
  ref.watch(contentVersionProvider);
  return ref.watch(adminRepositoryProvider).getImportJobs();
});

/// Content Studio: review queue — question candidates awaiting approval.
final candidatesProvider = FutureProvider((ref) {
  ref.watch(contentVersionProvider);
  return ref.watch(adminRepositoryProvider).getCandidates();
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

// ---------- adaptive learning engine (ADR-0008) ----------

/// No AI providers configured in V1; interfaces only.
final aiServicesProvider = Provider<AiServices>((ref) => AiServices.none);

final learnerModelRepositoryProvider = Provider<LearnerModelRepository>(
  (ref) => InMemoryLearnerModelRepository(),
);

final knowledgeGraphProvider = FutureProvider<KnowledgeGraph>((ref) async {
  ref.watch(contentVersionProvider);
  final content = ref.watch(contentRepositoryProvider);
  return buildKnowledgeGraph(
    await content.getTopics(),
    await content.getQuestions(),
  );
});

final learnerEngineProvider = Provider<LearnerEngine>((ref) {
  final graph =
      ref.watch(knowledgeGraphProvider).value ?? const KnowledgeGraph({});
  return LearnerEngine(graph: graph);
});

/// Holds the learner model; every answer event flows through here.
class LearnerModelController extends Notifier<adaptive.LearnerModel> {
  @override
  adaptive.LearnerModel build() {
    ref.read(learnerModelRepositoryProvider).load().then((m) => state = m);
    return const adaptive.LearnerModel();
  }

  Future<void> recordAnswer(adaptive.AnswerEvent event) async {
    state = ref.read(learnerEngineProvider).applyAnswer(state, event);
    await ref.read(learnerModelRepositoryProvider).save(state);
  }

  Future<void> recordMockExam(double scoreFraction) async {
    state = ref
        .read(learnerEngineProvider)
        .recordMockExam(state, scoreFraction);
    await ref.read(learnerModelRepositoryProvider).save(state);
  }
}

final learnerModelProvider =
    NotifierProvider<LearnerModelController, adaptive.LearnerModel>(
      LearnerModelController.new,
    );

final readinessProvider = FutureProvider<adaptive.ReadinessReport>((ref) async {
  final model = ref.watch(learnerModelProvider);
  final engine = ref.watch(learnerEngineProvider);
  final topics = await ref.watch(topicsProvider.future);
  final exam = await ref.watch(examProvider.future);
  return engine.readiness(
    model,
    allTopicIds: [for (final t in topics) t.id],
    passRatio: exam.passThreshold / exam.questionCount,
    now: DateTime.now(),
  );
});

final studyPlanProvider = FutureProvider<adaptive.StudyPlan>((ref) async {
  final model = ref.watch(learnerModelProvider);
  final engine = ref.watch(learnerEngineProvider);
  final topics = await ref.watch(topicsProvider.future);
  return engine.studyPlan(
    model,
    allTopicIds: [for (final t in topics) t.id],
    now: DateTime.now(),
  );
});

// ---------- practice session ----------

class PracticeState {
  const PracticeState({
    required this.questions,
    required this.index,
    required this.correctCount,
    required this.startedAt,
    required this.questionShownAt,
    this.selectedIndex,
    this.finished = false,
  });

  final List<Question> questions;
  final int index;
  final int correctCount;
  final DateTime startedAt;

  /// When the current question appeared — response-time input for the
  /// adaptive engine.
  final DateTime questionShownAt;

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
    DateTime? questionShownAt,
  }) => PracticeState(
    questions: questions,
    index: index ?? this.index,
    correctCount: correctCount ?? this.correctCount,
    startedAt: startedAt,
    questionShownAt: questionShownAt ?? this.questionShownAt,
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
    final now = DateTime.now();
    state = PracticeState(
      questions: questions,
      index: 0,
      correctCount: 0,
      startedAt: now,
      questionShownAt: now,
    );
  }

  Future<void> answer(int selectedIndex) async {
    final s = state;
    if (s == null || s.answered) return;
    final now = DateTime.now();
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
    await ref
        .read(learnerModelProvider.notifier)
        .recordAnswer(
          answerEventFor(
            s.current,
            correct: correct,
            responseSeconds:
                now.difference(s.questionShownAt).inMilliseconds / 1000,
            answeredAt: now,
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
      state = s.copyWith(
        index: s.index + 1,
        clearSelection: true,
        questionShownAt: DateTime.now(),
      );
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
    final learner = ref.read(learnerModelProvider.notifier);
    final now = DateTime.now();
    // Per-question timing is not captured in exam mode; approximate with
    // the session average so the engine still learns from exam answers.
    final avgSeconds =
        now.difference(s.startedAt).inSeconds / s.questions.length;
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
      await learner.recordAnswer(
        answerEventFor(
          q,
          correct: answer.correct,
          responseSeconds: avgSeconds,
          answeredAt: now,
        ),
      );
    }
    await learner.recordMockExam(
      result.total == 0 ? 0 : result.score / result.total,
    );
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
