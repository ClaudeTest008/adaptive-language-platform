import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionsProvider).value ?? const [];
    final bookmarks = ref.watch(bookmarksProvider).value ?? const {};
    final saved = questions.where((q) => bookmarks.contains(q.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: CenteredBody(
        child: saved.isEmpty
            ? const Center(
                child: Text(
                  'No bookmarks yet.\nSave questions while practicing.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: saved.length,
                itemBuilder: (context, i) {
                  final q = saved[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(
                        q.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove bookmark',
                        onPressed: () async {
                          await ref
                              .read(studyRepositoryProvider)
                              .toggleBookmark(q.id);
                          ref.read(studyVersionProvider.notifier).state++;
                        },
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Answer: ${q.answers[q.correctIndex]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ExplanationCard(explanation: q.explanation),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
