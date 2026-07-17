import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/story.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Stories tab (ADR-0020): level-matched short stories. Reading feeds the
/// same knowledge graph; a story recommends itself by the learner's CEFR
/// level and how much it overlaps their weak concepts.
class LanguageStoriesScreen extends ConsumerWidget {
  const LanguageStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Stories'),
      ),
      body: AtmosphericBackground(
        child: storiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load stories:\n$e')),
        data: (stories) {
          if (stories.isEmpty) {
            return const Center(child: Text('No stories for your level yet.'));
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.lg),
                children: [
                  Text(
                    'Matched to your level — read, then tap Listen',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  for (final (i, s) in stories.indexed)
                    FadeInUp(delayMs: i * 60, child: _StoryCard(story: s)),
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

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () =>
            context.push('/story/${Uri.encodeComponent(story.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.tertiaryContainer,
                      scheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book, color: scheme.onTertiaryContainer),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(story.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(story.level.name.toUpperCase()),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${story.phrases.length} phrases'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
