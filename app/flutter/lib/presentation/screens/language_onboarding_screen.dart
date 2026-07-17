import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../language_providers.dart';
import '../providers.dart';
import '../ui.dart';

/// First-run onboarding (Phase 10): an immersive, atmospheric flow that
/// picks the target language and sets the learner's goals before the
/// dashboard. Writes the same providers the Lab uses (`selectedLanguage`,
/// `learnerGoals`) then flips [onboardingSeenProvider] and enters the app.
class LanguageOnboardingScreen extends ConsumerStatefulWidget {
  const LanguageOnboardingScreen({super.key});

  @override
  ConsumerState<LanguageOnboardingScreen> createState() =>
      _LanguageOnboardingScreenState();
}

class _LanguageOnboardingScreenState
    extends ConsumerState<LanguageOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _pages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: AppMotion.curve,
      );
    } else {
      ref.read(onboardingSeenProvider.notifier).state = true;
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const SizedBox(height: AppSpace.lg),
                  _ProgressDots(page: _page, count: _pages),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: const [
                        _WelcomePage(),
                        _LanguagePage(),
                        _GoalsPage(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _next,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _page < _pages - 1
                                  ? 'Continue'
                                  : 'Start learning',
                              style:
                                  Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Icon(
                              _page < _pages - 1
                                  ? Icons.arrow_forward
                                  : Icons.rocket_launch,
                              color: scheme.onPrimary,
                              size: 20,
                            ),
                          ],
                        ),
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

/// Thin segmented progress indicator at the top of the flow.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= page
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(Icons.language, size: 48, color: scheme.onPrimary),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          FadeInUp(
            delayMs: 80,
            child: Text(
              'Your personal\nlanguage teacher',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          FadeInUp(
            delayMs: 160,
            child: Text(
              'An adaptive AI tutor that learns how you learn — repairing '
              'misconceptions, pacing to your goals, and speaking with you '
              'in real conversations.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLanguageProvider);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you\nlike to learn?',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          for (final (i, l) in availableLanguages.indexed)
            FadeInUp(
              delayMs: i * 70,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: _LanguageTile(
                  flag: l.flag,
                  name: l.name,
                  selected: l.code == selected,
                  onTap: () => ref
                      .read(selectedLanguageProvider.notifier)
                      .state = l.code,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.flag,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.lg,
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                : null,
          ),
        ],
      ),
    );
  }
}

class _GoalsPage extends ConsumerWidget {
  const _GoalsPage();

  static const _levels = [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(learnerGoalsProvider);
    final ctrl = ref.read(learnerGoalsProvider.notifier);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your pace',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily goal', style: text.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${goals.minutesPerDay} minutes / day',
                  style: text.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Slider(
                  value: goals.minutesPerDay.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${goals.minutesPerDay} min',
                  onChanged: (v) => ctrl.setMinutes(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target level', style: text.titleMedium),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  children: [
                    for (final level in _levels)
                      ChoiceChip(
                        label: Text(level.name.toUpperCase()),
                        selected: goals.targetLevel == level,
                        onSelected: (_) => ctrl.setTargetLevel(level),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'You can change these any time from the Lab.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
