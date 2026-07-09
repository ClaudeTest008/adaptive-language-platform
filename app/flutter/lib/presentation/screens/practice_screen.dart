import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models.dart';
import '../providers.dart';
import '../widgets.dart';

class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);
    final bookmarks = ref.watch(bookmarksProvider).value ?? const {};

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session complete')),
        body: CenteredBody(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '${state.correctCount} / ${state.questions.length}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const Text('correct'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    controller.reset();
                    context.go('/');
                  },
                  child: const Text('Back to dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = state.current;
    final bookmarked = bookmarks.contains(q.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${state.index + 1} of ${state.questions.length}'),
        actions: [
          IconButton(
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            onPressed: () async {
              await ref.read(studyRepositoryProvider).toggleBookmark(q.id);
              ref.read(studyVersionProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LinearProgressIndicator(
              value: (state.index + 1) / state.questions.length,
            ),
            const SizedBox(height: 16),
            Text(q.text, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (var i = 0; i < q.answers.length; i++)
              AnswerTile(
                text: q.answers[i],
                index: i,
                selectedIndex: state.selectedIndex,
                correctIndex: state.answered ? q.correctIndex : null,
                onTap: state.answered ? null : () => controller.answer(i),
              ),
            if (state.answered) ...[
              const SizedBox(height: 16),
              ExplanationCard(explanation: q.explanation),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => controller.next(type: AttemptType.practice),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    state.index + 1 < state.questions.length
                        ? 'Next question'
                        : 'Finish session',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
