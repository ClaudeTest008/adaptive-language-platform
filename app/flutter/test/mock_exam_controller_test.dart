import 'package:adaptive_exam_platform/domain/models.dart';
import 'package:adaptive_exam_platform/presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock exam controller: select answers, submit, score and persist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(mockExamControllerProvider.notifier);
    await controller.start();

    var state = container.read(mockExamControllerProvider)!;
    expect(state.questions.length, 10);
    expect(state.remainingSeconds, 15 * 60);

    // Answer every question correctly.
    for (final q in state.questions) {
      controller.select(q.id, q.correctIndex);
    }
    state = container.read(mockExamControllerProvider)!;
    expect(state.selections.length, 10);

    await controller.submit();
    state = container.read(mockExamControllerProvider)!;
    expect(state.result, isNotNull);
    expect(state.result!.score, 10);
    expect(state.result!.passed, isTrue);

    // Attempt persisted with per-question answers.
    final attempts =
        await container.read(studyRepositoryProvider).getAttempts();
    expect(attempts, hasLength(1));
    expect(attempts.first.type, AttemptType.mock);
    expect(attempts.first.passed, isTrue);
    expect(attempts.first.answers, hasLength(10));

    controller.reset();
    expect(container.read(mockExamControllerProvider), isNull);
  });

  test('mock exam controller: unanswered submission fails and feeds incorrect pool',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(mockExamControllerProvider.notifier);
    await controller.start();
    final first = container.read(mockExamControllerProvider)!.questions.first;
    controller.select(first.id, first.correctIndex);

    await controller.submit();
    final state = container.read(mockExamControllerProvider)!;
    expect(state.result!.score, 1);
    expect(state.result!.passed, isFalse);

    final incorrect =
        await container.read(studyRepositoryProvider).getIncorrectQuestionIds();
    expect(incorrect.length, 9); // the unanswered ones
    expect(incorrect, isNot(contains(first.id)));
  });
}
