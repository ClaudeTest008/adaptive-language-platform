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
                    'Short stories & classics, matched to your level. '
                    'Read, listen, then check your understanding.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  ..._groupedByLevel(context, stories),
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

/// Stories grouped under CEFR-level section headers, easiest first — a
/// clearer hierarchy than one long flat list.
List<Widget> _groupedByLevel(BuildContext context, List<Story> stories) {
  final out = <Widget>[];
  String? currentLevel;
  var i = 0;
  for (final s in stories) {
    final lvl = s.level.name.toUpperCase();
    if (lvl != currentLevel) {
      currentLevel = lvl;
      out.add(
        Padding(
          padding: EdgeInsets.only(
            top: out.isEmpty ? 0 : AppSpace.md,
            bottom: AppSpace.sm,
          ),
          child: Text(
            'Level $lvl',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }
    out.add(FadeInUp(delayMs: (i++) * 50, child: _StoryCard(story: s)));
  }
  return out;
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
                      runSpacing: 4,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(story.level.name.toUpperCase()),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${story.phrases.length} phrases'),
                        ),
                        if (story.questions.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.quiz_outlined, size: 14),
                            label: const Text('Quiz'),
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
