import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/entities.dart';
import '../language_providers.dart';
import '../ui.dart';

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
    final tones = AppTones.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.lg,
                  AppSpace.xl,
                  AppSpace.xxl,
                ),
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        size: 42,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Your goals',
                    style: TextStyle(
                      color: tones.ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  FadeInUp(
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardTitle('Daily time'),
                          const SizedBox(height: AppSpace.xs),
                          _CardHint(
                            'How long do you want to study each day? Your plan is '
                            'budgeted to fit.',
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            '${goals.minutesPerDay} minutes / day',
                            style: TextStyle(
                              color: tones.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          MinutesSlider(
                            minutes: goals.minutesPerDay,
                            onChanged: notifier.setMinutes,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FadeInUp(
                    delayMs: 80,
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardTitle('Target level'),
                          const SizedBox(height: AppSpace.xs),
                          _CardHint(
                            'What CEFR level are you aiming for? Stories up to this '
                            'level appear in your queue.',
                          ),
                          const SizedBox(height: AppSpace.md),
                          Wrap(
                            spacing: AppSpace.sm,
                            runSpacing: AppSpace.sm,
                            children: [
                              for (final level in _levels)
                                LevelChip(
                                  level: level,
                                  selected: goals.targetLevel == level,
                                  onSelected: () =>
                                      notifier.setTargetLevel(level),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FadeInUp(
                    delayMs: 160,
                    child: SoftCard(
                      tint: AppTint.mint,
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: tones.onTint(AppTint.mint),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              'Today\'s plan will fit ${goals.minutesPerDay} '
                              'minutes, aiming for ${goals.targetLevel.name.toUpperCase()}.',
                              style: TextStyle(
                                color: tones.onTint(AppTint.mint),
                                fontSize: 14.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Text(
      text,
      style: TextStyle(
        color: tones.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _CardHint extends StatelessWidget {
  const _CardHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Text(
      text,
      style: TextStyle(color: tones.inkSoft, fontSize: 13.5, height: 1.35),
    );
  }
}

/// Design-system slider for the daily-minutes goal. Shared with onboarding
/// so both surfaces read identically in light and dark.
class MinutesSlider extends StatelessWidget {
  const MinutesSlider({
    super.key,
    required this.minutes,
    required this.onChanged,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: tones.ink,
        inactiveTrackColor: tones.cardMuted,
        thumbColor: tones.ink,
        overlayColor: tones.ink.withValues(alpha: 0.10),
        valueIndicatorColor: tones.ink,
        valueIndicatorTextStyle: TextStyle(
          color: tones.onAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Slider(
        value: minutes.toDouble(),
        min: 5,
        max: 60,
        divisions: 11,
        label: '$minutes min',
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}

/// CEFR level chip. Stays a [ChoiceChip] (widget tests target it by type)
/// but takes its colours from the design tokens.
class LevelChip extends StatelessWidget {
  const LevelChip({
    super.key,
    required this.level,
    required this.selected,
    required this.onSelected,
  });

  final CefrLevel level;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return ChoiceChip(
      label: Text(level.name.toUpperCase()),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      backgroundColor: tones.cardMuted,
      selectedColor: tones.accent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected ? tones.onAccent : tones.ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
    );
  }
}
