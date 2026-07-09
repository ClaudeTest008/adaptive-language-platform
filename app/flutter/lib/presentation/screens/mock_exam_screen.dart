import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../widgets.dart';

class MockExamScreen extends ConsumerWidget {
  const MockExamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockExamControllerProvider);
    final controller = ref.read(mockExamControllerProvider.notifier);

    if (state == null) return _StartView(onStart: controller.start);
    if (state.finished) {
      return _ResultView(state: state, controller: controller);
    }
    return _SessionView(state: state, controller: controller);
  }
}

class _StartView extends ConsumerWidget {
  const _StartView({required this.onStart});

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = ref.watch(examProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Mock Exam')),
      body: CenteredBody(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                exam?.name ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (exam != null)
                Text(
                  '${exam.questionCount} random questions · '
                  '${exam.timeLimitMinutes} minutes · '
                  'pass with ${exam.passThreshold}+',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Start exam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({required this.state, required this.controller});

  final MockExamState state;
  final MockExamController controller;

  String get _clock {
    final m = state.remainingSeconds ~/ 60;
    final s = state.remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final answered = state.selections.length;
    final urgent = state.remainingSeconds <= 60;
    return Scaffold(
      appBar: AppBar(
        title: Text('$answered / ${state.questions.length} answered'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _clock,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: urgent ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CenteredBody(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.questions.length + 1,
          itemBuilder: (context, i) {
            if (i == state.questions.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: FilledButton(
                  onPressed: controller.submit,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Submit exam'),
                  ),
                ),
              );
            }
            final q = state.questions[i];
            final selected = state.selections[q.id];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ${q.text}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (var a = 0; a < q.answers.length; a++)
                      RadioListTile<int>(
                        dense: true,
                        value: a,
                        // ignore: deprecated_member_use
                        groupValue: selected,
                        // ignore: deprecated_member_use
                        onChanged: (v) => controller.select(q.id, v!),
                        title: Text(q.answers[a]),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.state, required this.controller});

  final MockExamState state;
  final MockExamController controller;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Result')),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            Icon(
              result.passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 72,
              color: result.passed ? Colors.green : scheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              result.passed ? 'PASSED' : 'FAILED',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: result.passed ? Colors.green : scheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${result.score} / ${result.total}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                controller.reset();
                context.go('/');
              },
              child: const Text('Back to dashboard'),
            ),
            const Divider(height: 32),
            Text('Review', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < state.questions.length; i++)
              _ReviewTile(
                index: i,
                question: state.questions[i],
                selected: state.selections[state.questions[i].id],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final dynamic question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final correct = selected != null && selected == question.correctIndex;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          correct ? Icons.check_circle : Icons.cancel,
          color: correct ? Colors.green : Theme.of(context).colorScheme.error,
        ),
        title: Text(
          '${index + 1}. ${question.text}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected == null
                      ? 'Not answered'
                      : 'Your answer: ${question.answers[selected!]}',
                ),
                Text(
                  'Correct answer: '
                  '${question.answers[question.correctIndex]}',
                ),
                const SizedBox(height: 8),
                ExplanationCard(explanation: question.explanation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
