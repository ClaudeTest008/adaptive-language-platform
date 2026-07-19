import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../language_providers.dart';
import '../providers.dart';
import '../ui.dart';
import 'language_goals_screen.dart';

/// Page-title style shared by the three onboarding pages: large, tight, bold.
TextStyle _title(AppTones tones) => TextStyle(
      color: tones.ink,
      fontSize: 27,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    );

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
    final last = _page == _pages - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const SizedBox(height: AppSpace.lg),
                  _ProgressBars(page: _page, count: _pages),
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
                    child: PrimaryButton(
                      label: last ? 'Start learning' : 'Continue',
                      icon: last ? Icons.rocket_launch : Icons.arrow_forward,
                      onPressed: _next,
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

/// Slim rounded progress bars at the top of the flow.
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= page ? tones.ink : tones.cardMuted,
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
    final tones = AppTones.of(context);
    // Scrollable: in landscape or at a large text scale the page is taller
    // than the viewport, and a fixed Column overflowed instead of scrolling.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tones.tint(AppTint.sun),
              ),
              child: Icon(
                Icons.language,
                size: 50,
                color: tones.onTint(AppTint.sun),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          FadeInUp(
            delayMs: 80,
            child: Text(
              'Your personal\nlanguage teacher',
              style: _title(tones),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          FadeInUp(
            delayMs: 160,
            child: Text(
              'An adaptive AI tutor that learns how you learn — repairing '
              'misconceptions, pacing to your goals, and speaking with you '
              'in real conversations.',
              style: TextStyle(
                color: tones.inkSoft,
                fontSize: 15.5,
                height: 1.45,
              ),
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
    final tones = AppTones.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What would you\nlike to learn?', style: _title(tones)),
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
    final tones = AppTones.of(context);
    return SoftCard(
      onTap: onTap,
      radius: AppRadius.tile,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: tones.ink,
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? tones.accent : Colors.transparent,
              border: Border.all(
                color: selected ? tones.accent : tones.inkSoft,
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 16, color: tones.onAccent)
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
    final tones = AppTones.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set your pace', style: _title(tones)),
          const SizedBox(height: AppSpace.xl),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily goal',
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
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
                  onChanged: ctrl.setMinutes,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target level',
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  children: [
                    for (final level in _levels)
                      LevelChip(
                        level: level,
                        selected: goals.targetLevel == level,
                        onSelected: () => ctrl.setTargetLevel(level),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'You can change these any time from the Lab.',
            style: TextStyle(color: tones.inkSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

