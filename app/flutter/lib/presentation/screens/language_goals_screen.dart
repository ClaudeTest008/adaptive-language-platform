import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/entities.dart';
import '../language_providers.dart';

/// Learner goals (ADR-0026): daily minutes budget + target CEFR level.
/// Minutes drive the lesson engine's time allocation; the target level
/// caps the story queue so learners can read ahead.
class LanguageGoalsScreen extends ConsumerWidget {
  const LanguageGoalsScreen({super.key});

  static const _levels = [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(learnerGoalsProvider);
    final notifier = ref.read(learnerGoalsProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your goals')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Daily time', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'How long do you want to study each day? Your plan is '
                'budgeted to fit.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${goals.minutesPerDay} minutes / day',
                        style: text.headlineSmall,
                      ),
                      Slider(
                        value: goals.minutesPerDay.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 11,
                        label: '${goals.minutesPerDay} min',
                        onChanged: (v) => notifier.setMinutes(v.round()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Target level', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'What CEFR level are you aiming for? Stories up to this '
                'level appear in your queue.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final level in _levels)
                    ChoiceChip(
                      label: Text(level.name.toUpperCase()),
                      selected: goals.targetLevel == level,
                      onSelected: (_) => notifier.setTargetLevel(level),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Today\'s plan will fit ${goals.minutesPerDay} '
                          'minutes, aiming for ${goals.targetLevel.name.toUpperCase()}.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
