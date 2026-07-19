import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/relationships.dart';
import '../language_providers.dart';
import '../ui.dart';

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
    final tones = AppTones.of(context);
    final curriculum = curriculumAsync.value;
    final node = curriculum?.graph[conceptId];

    if (curriculum == null || node == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Concept'),
        ),
        body: AtmosphericBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Text(
                curriculumAsync.hasError
                    ? 'Curriculum failed to load:\n${curriculumAsync.error}'
                    : curriculum == null
                    ? 'Loading…'
                    : 'Unknown concept',
                textAlign: TextAlign.center,
                style: TextStyle(color: tones.inkSoft, fontSize: 15),
              ),
            ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(node.name),
      ),
      body: AtmosphericBackground(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          // Not a lazy list: the page is bounded and every section stays in
          // the tree, so nothing pops in and out while scrolling.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  SoftChip(icon: Icons.layers, label: node.tier.name),
                  if (node.skill != null)
                    SoftChip(
                      icon: Icons.category,
                      label: node.skill!.name,
                      tint: AppTint.sage,
                    ),
                  if (node.cefr != null)
                    SoftChip(
                      icon: Icons.signal_cellular_alt,
                      label: node.cefr!.name.toUpperCase(),
                      tint: AppTint.lilac,
                    ),
                ],
              ),
              if (node is GrammarConceptNode) ...[
                const SizedBox(height: AppSpace.md),
                SoftCard(
                  tint: AppTint.sun,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.pattern,
                        style: TextStyle(
                          color: tones.onTint(AppTint.sun),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (node.explanation != null) ...[
                        const SizedBox(height: AppSpace.sm - 2),
                        Text(
                          node.explanation!,
                          style: TextStyle(
                            color: tones
                                .onTint(AppTint.sun)
                                .withValues(alpha: 0.85),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'Adaptive signals'),
              const SizedBox(height: AppSpace.md),
              SoftCard(
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
                      Divider(height: AppSpace.xl, color: tones.hairline),
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
              if (misconceptions.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Misconceptions'),
                const SizedBox(height: AppSpace.md),
                for (final m in misconceptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: SoftCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sync_problem, color: scheme.error),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.explanation,
                                  style: TextStyle(
                                    color: tones.ink,
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpace.xs),
                                Text(
                                  'seen ${m.occurrences}× · source: '
                                  '${m.interferenceSource}',
                                  style: TextStyle(
                                    color: tones.inkSoft,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (relations.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Knowledge graph'),
                const SizedBox(height: AppSpace.md),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpace.sm,
                    horizontal: AppSpace.sm,
                  ),
                  child: Column(
                    children: [
                      for (final r in relations)
                        _RelationRow(
                          icon: _relationIcons[r.type],
                          warn: r.type ==
                                  LanguageRelationType.interferesWith ||
                              r.type == LanguageRelationType.falseFriend,
                          title: '${r.type.name} → '
                              '${curriculum.graph[r.from == conceptId ? r.to : r.from]?.name ?? (r.from == conceptId ? r.to : r.from)}',
                          note: r.note,
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
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Pattern family'),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final c in children)
                      SoftChip(
                        label: c.name,
                        onTap: () => context.push(
                          '/language/concept/${Uri.encodeComponent(c.conceptId)}',
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(
                title: 'Simulate an answer (drives the real engine)',
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: _SimulateButton(
                      icon: Icons.check,
                      label: 'Correct',
                      color: tones.solid(AppTint.mint),
                      onPressed: () => ref
                          .read(languageLearnerProvider.notifier)
                          .recordAnswer(
                            node: node,
                            correct: true,
                            responseSeconds: 3,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: _SimulateButton(
                      icon: Icons.close,
                      label: 'Wrong',
                      color: scheme.error,
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
              const SizedBox(height: AppSpace.xl),
            ],
          ),
          ),
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
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final good = inverted ? value < 0.4 : value >= 0.6;
    final color = good ? tones.solid(AppTint.mint) : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs + 2),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: tones.cardMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One knowledge-graph edge — tappable row inside the graph card.
class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.icon,
    required this.warn,
    required this.title,
    required this.note,
    required this.onTap,
  });

  final IconData? icon;
  final bool warn;
  final String title;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.md - 2,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: warn ? scheme.error : tones.solid(AppTint.lilac),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tones.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tones.inkSoft, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Icon(Icons.chevron_right, size: 18, color: tones.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// Tinted outline action used by the simulate row.
class _SimulateButton extends StatelessWidget {
  const _SimulateButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.10),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
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
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tones.inkSoft),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tones.inkSoft, fontSize: 13.5),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: tones.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
