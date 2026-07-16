import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/relationships.dart';
import '../language_providers.dart';

/// Concept detail: knowledge-graph relationships, misconceptions and
/// live adaptive signals for one language concept. The simulate buttons
/// drive real answer events through the unchanged core engine.
class LanguageConceptScreen extends ConsumerWidget {
  const LanguageConceptScreen({super.key, required this.conceptId});

  final String conceptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);
    final learner = ref.watch(languageLearnerProvider);
    final scheme = Theme.of(context).colorScheme;
    final curriculum = curriculumAsync.value;
    final node = curriculum?.graph[conceptId];

    if (curriculum == null || node == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Concept')),
        body: Center(
          child: Text(
            curriculumAsync.hasError
                ? 'Curriculum failed to load:\n${curriculumAsync.error}'
                : curriculum == null
                ? 'Loading…'
                : 'Unknown concept',
          ),
        ),
      );
    }

    final stats = learner.model.concepts[conceptId];
    final signals = learner.signals[conceptId];
    final misconceptions = learner.misconceptions.forConcept(conceptId);
    final relations = curriculum.graph.touching(conceptId);
    final children = [
      for (final n in curriculum.graph.nodes.values)
        if (n.parent?.conceptId == conceptId) n,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(node.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.layers, size: 16),
                    label: Text(node.tier.name),
                  ),
                  if (node.skill != null)
                    Chip(
                      avatar: const Icon(Icons.category, size: 16),
                      label: Text(node.skill!.name),
                    ),
                  if (node.cefr != null)
                    Chip(
                      avatar: const Icon(Icons.signal_cellular_alt, size: 16),
                      label: Text(node.cefr!.name.toUpperCase()),
                    ),
                ],
              ),
              if (node is GrammarConceptNode) ...[
                const SizedBox(height: 12),
                Card(
                  color: scheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.pattern,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                        if (node.explanation != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            node.explanation!,
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Adaptive signals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SignalRow(
                        label: 'Mastery (core engine)',
                        value: stats?.mastery ?? 0,
                      ),
                      _SignalRow(
                        label: 'Recall difficulty',
                        value: signals.recallDifficulty,
                        inverted: true,
                      ),
                      _SignalRow(
                        label: 'L1 interference',
                        value: signals.nativeInterference,
                        inverted: true,
                      ),
                      const Divider(height: 20),
                      _FactRow(
                        icon: Icons.repeat,
                        label: 'Attempts',
                        value: '${stats?.attempts ?? 0}'
                            ' (${stats?.correct ?? 0} correct)',
                      ),
                      _FactRow(
                        icon: Icons.speed,
                        label: 'Recall speed',
                        value: signals.recallSpeedMs == null
                            ? '—'
                            : '${(signals.recallSpeedMs! / 1000).toStringAsFixed(1)}s',
                      ),
                      _FactRow(
                        icon: Icons.translate,
                        label: 'Transfer errors',
                        value: '${signals.grammarTransferErrors}',
                      ),
                      _FactRow(
                        icon: Icons.trending_up,
                        label: 'Times used',
                        value: '${signals.usageFrequency}',
                      ),
                    ],
                  ),
                ),
              ),
              if (misconceptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Misconceptions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final m in misconceptions)
                  Card(
                    color: scheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.sync_problem,
                        color: scheme.onErrorContainer,
                      ),
                      title: Text(
                        m.explanation,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      subtitle: Text(
                        'seen ${m.occurrences}× · source: ${m.interferenceSource}',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
              ],
              if (relations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Knowledge graph',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final r in relations)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            _relationIcons[r.type],
                            color: r.type ==
                                        LanguageRelationType.interferesWith ||
                                    r.type == LanguageRelationType.falseFriend
                                ? scheme.error
                                : scheme.primary,
                          ),
                          title: Text(
                            '${r.type.name} → '
                            '${curriculum.graph[r.from == conceptId ? r.to : r.from]?.name ?? (r.from == conceptId ? r.to : r.from)}',
                          ),
                          subtitle: r.note == null ? null : Text(r.note!),
                          onTap: () {
                            final other = r.from == conceptId ? r.to : r.from;
                            if (curriculum.graph[other] != null) {
                              context.push(
                                '/language/concept/${Uri.encodeComponent(other)}',
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
              if (children.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Pattern family',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in children)
                      ActionChip(
                        label: Text(c.name),
                        onPressed: () => context.push(
                          '/language/concept/${Uri.encodeComponent(c.conceptId)}',
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Simulate an answer (drives the real engine)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.check),
                      label: const Text('Correct'),
                      onPressed: () => ref
                          .read(languageLearnerProvider.notifier)
                          .recordAnswer(
                            node: node,
                            correct: true,
                            responseSeconds: 3,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Wrong'),
                      onPressed: () => ref
                          .read(languageLearnerProvider.notifier)
                          .recordAnswer(
                            node: node,
                            correct: false,
                            responseSeconds: 8,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _relationIcons = {
    LanguageRelationType.requires: Icons.lock,
    LanguageRelationType.buildsOn: Icons.stairs,
    LanguageRelationType.interferesWith: Icons.sync_problem,
    LanguageRelationType.culturalContext: Icons.public,
    LanguageRelationType.falseFriend: Icons.compare_arrows,
    LanguageRelationType.relatedTo: Icons.link,
  };
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.value,
    this.inverted = false,
  });

  final String label;
  final double value;

  /// Inverted: high = bad (difficulty, interference).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = inverted ? value < 0.4 : value >= 0.6;
    final color = good ? scheme.primary : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
