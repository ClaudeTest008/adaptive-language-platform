import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/ingestion.dart';
import '../language_providers.dart';

/// Content Studio (ADR-0025): paste target-language text, preview the
/// extracted review candidates (vocabulary, phrases, sentences, idioms,
/// cultural notes) mapped to curriculum concepts, and approve/reject.
/// Admin-only — the human review queue for new language material.
class LanguageContentScreen extends ConsumerStatefulWidget {
  const LanguageContentScreen({super.key});

  @override
  ConsumerState<LanguageContentScreen> createState() =>
      _LanguageContentScreenState();
}

class _LanguageContentScreenState
    extends ConsumerState<LanguageContentScreen> {
  final _input = TextEditingController();

  static const _sample =
      'María tiene mucha hambre. Va a un pequeño restaurante en Sevilla. '
      'El camarero habla español despacio. María quiere comer una manzana '
      'roja. También tiene sed y tiene prisa. En España la comida es a las '
      'tres de la tarde. Ahora María está contenta.';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the curriculum warm so ingest() has the graph ready.
    ref.watch(curriculumProvider);
    final studio = ref.watch(contentStudioProvider);
    final result = studio.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Studio'),
        actions: [
          if (result != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear',
              onPressed: () {
                _input.clear();
                ref.read(contentStudioProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Paste a passage in the target language. We extract '
                'vocabulary, phrases, sentences, idioms and cultural notes '
                'for you to review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Paste text here…',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Extract'),
                      onPressed: () => ref
                          .read(contentStudioProvider.notifier)
                          .ingest(_input.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      _input.text = _sample;
                      ref
                          .read(contentStudioProvider.notifier)
                          .ingest(_sample);
                    },
                    child: const Text('Use sample'),
                  ),
                ],
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                _Summary(result: result),
                const SizedBox(height: 8),
                for (final kind in ContentKind.values)
                  _KindSection(
                    kind: kind,
                    items: result.ofKind(kind),
                    review: studio.review,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final IngestionResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.candidates.length} candidates · '
              '${result.difficulty.name.toUpperCase()} · '
              '${result.candidates.where((c) => c.mapped).length} mapped to curriculum',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            if (result.topics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in result.topics)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(t),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindSection extends ConsumerWidget {
  const _KindSection({
    required this.kind,
    required this.items,
    required this.review,
  });

  final ContentKind kind;
  final List<ContentCandidate> items;
  final ContentReviewLog review;

  static const _titles = {
    ContentKind.vocabulary: ('Vocabulary', Icons.style),
    ContentKind.phrase: ('Phrases', Icons.short_text),
    ContentKind.sentence: ('Example sentences', Icons.notes),
    ContentKind.idiom: ('Idioms', Icons.emoji_objects),
    ContentKind.culturalNote: ('Cultural notes', Icons.public),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (title, icon) = _titles[kind]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text('$title (${items.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 6),
        for (final c in items)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.text),
                        if (c.translation != null)
                          Text(
                            c.translation!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        const SizedBox(height: 2),
                        _StatusChip(candidate: c, review: review),
                      ],
                    ),
                  ),
                  if (review.isPending(c.id)) ...[
                    IconButton(
                      icon: Icon(Icons.check_circle, color: scheme.primary),
                      tooltip: 'Approve',
                      onPressed: () => ref
                          .read(contentStudioProvider.notifier)
                          .approve(c.id),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined, color: scheme.error),
                      tooltip: 'Reject',
                      onPressed: () => ref
                          .read(contentStudioProvider.notifier)
                          .reject(c.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.candidate, required this.review});

  final ContentCandidate candidate;
  final ContentReviewLog review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = review.approved.contains(candidate.id)
        ? ('Approved', scheme.primary)
        : review.rejected.contains(candidate.id)
        ? ('Rejected', scheme.error)
        : candidate.mapped
        ? ('Maps to ${candidate.conceptId!.split(':').last}', scheme.tertiary)
        : ('New — ${candidate.note ?? "review"}', scheme.onSurfaceVariant);
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}
