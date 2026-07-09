import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../widgets.dart';

class PracticeSetupScreen extends ConsumerWidget {
  const PracticeSetupScreen({super.key});

  Future<void> _start(
    BuildContext context,
    WidgetRef ref, {
    String? topicId,
    bool reviewIncorrect = false,
  }) async {
    final content = ref.read(contentRepositoryProvider);
    var questions = await content.getQuestions(topicId: topicId);
    if (reviewIncorrect) {
      final incorrectIds = await ref
          .read(studyRepositoryProvider)
          .getIncorrectQuestionIds();
      questions = questions.where((q) => incorrectIds.contains(q.id)).toList();
    }
    if (questions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No questions available for this selection.'),
          ),
        );
      }
      return;
    }
    questions.shuffle();
    ref.read(practiceControllerProvider.notifier).start(questions);
    if (context.mounted) context.push('/practice/session');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    final incorrect = ref.watch(incorrectIdsProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: CenteredBody(
        child: topics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load topics: $e')),
          data: (list) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('All topics'),
                  subtitle: const Text('Interleaved practice across topics'),
                  onTap: () => _start(context, ref),
                ),
              ),
              if (incorrect.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.replay),
                    title: Text('Review incorrect (${incorrect.length})'),
                    subtitle: const Text('Questions you previously got wrong'),
                    onTap: () => _start(context, ref, reviewIncorrect: true),
                  ),
                ),
              const Divider(height: 32),
              for (final t in list)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.topic),
                    title: Text(t.name),
                    onTap: () => _start(context, ref, topicId: t.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
