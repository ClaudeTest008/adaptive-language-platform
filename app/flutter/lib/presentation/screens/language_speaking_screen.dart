import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../language_providers.dart';
import '../ui.dart';

/// Speaking practice (ADR-0020): hear the target, say it, get a
/// pronunciation score. Each attempt records pronunciationConfidence and
/// nudges the concept's mastery — speaking is production, real evidence.
class LanguageSpeakingScreen extends ConsumerWidget {
  const LanguageSpeakingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(speakingProvider);
    final speechAvailable = ref.watch(speechServiceProvider).available;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Speaking'),
        actions: [
          if (session != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.md),
              child: CircleIconButton(
                icon: Icons.close_rounded,
                size: 42,
                tooltip: 'End',
                onTap: () => ref.read(speakingProvider.notifier).reset(),
              ),
            ),
        ],
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: session == null
                ? _Intro(speechAvailable: speechAvailable)
                : session.finished
                    ? _Summary(session: session)
                    : _Drill(session: session),
          ),
        ),
      ),
    );
  }
}

/// The iridescent voice orb from the design: a soft, slowly-turning sphere
/// of blended colour. Drawn, not an asset — cheap and theme-independent.
class _Orb extends StatefulWidget {
  const _Orb({this.size = 190, this.active = false});

  final double size;
  final bool active;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final turn = _c.value * 2 * math.pi;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient bloom.
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB98CE8).withValues(alpha: 0.28),
                      const Color(0xFFB98CE8).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              // The sphere: a turning sweep of iridescent colour.
              Container(
                width: widget.size * 0.74,
                height: widget.size * 0.74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(turn),
                    colors: const [
                      Color(0xFFF2C8A0),
                      Color(0xFFE79BD0),
                      Color(0xFF9B8CF0),
                      Color(0xFF7FD8E8),
                      Color(0xFFBEE9B4),
                      Color(0xFFF7D98C),
                      Color(0xFFF2C8A0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9B8CF0)
                          .withValues(alpha: widget.active ? 0.45 : 0.28),
                      blurRadius: 34,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Specular highlight — reads as a lit 3D surface.
              Align(
                alignment: Alignment(-0.28 + 0.06 * math.cos(turn), -0.34),
                child: Container(
                  width: widget.size * 0.26,
                  height: widget.size * 0.18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.75),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Big centred prompt in the design's two-tone style: the phrase to say in
/// full ink, its translation trailing in a muted tone.
class _PromptText extends StatelessWidget {
  const _PromptText({required this.target, this.translation});

  final String target;
  final String? translation;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: target,
            style: TextStyle(
              color: tones.ink,
              fontSize: 25,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (translation != null && translation!.trim().isNotEmpty)
            TextSpan(
              text: '  $translation',
              style: TextStyle(
                color: tones.inkSoft,
                fontSize: 25,
                height: 1.35,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro({required this.speechAvailable});

  final bool speechAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Say it out loud,\nand I will listen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tones.ink,
              fontSize: 27,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          const FadeInUp(child: _Orb()),
          const SizedBox(height: AppSpace.xxl),
          Text(
            'Hear a word or phrase, say it aloud, and get a pronunciation '
            'score. Your weakest concepts come first.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tones.inkSoft,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (!speechAvailable) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              'Voice is unavailable on this device — you can still run the '
              'drills.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: 'Start drills',
            icon: Icons.arrow_forward,
            onPressed: () => ref.read(speakingProvider.notifier).start(),
          ),
        ],
      ),
    );
  }
}

class _Drill extends ConsumerWidget {
  const _Drill({required this.session});

  final SpeakingState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final drill = session.current;
    final ctrl = ref.read(speakingProvider.notifier);
    final last = session.index + 1 >= session.drills.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (session.index + 1) / session.drills.length,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Text(
                '${session.index + 1}/${session.drills.length}',
                style: TextStyle(
                  color: tones.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // The prompt + orb own the middle of the screen; the attempt UI sits
        // at the bottom. Scrollable so a tall feedback card never overflows.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl,
              vertical: AppSpace.lg,
            ),
            child: Column(
              children: [
                FadeInUp(
                  key: ValueKey(session.index),
                  child: _Orb(size: 168, active: session.listening),
                ),
                const SizedBox(height: AppSpace.xl),
                _PromptText(
                  target: drill.target,
                  translation: drill.translation,
                ),
                const SizedBox(height: AppSpace.lg),
                TextButton.icon(
                  icon: const Icon(Icons.volume_up_rounded, size: 19),
                  label: const Text('Hear it'),
                  onPressed: ctrl.playTarget,
                ),
                if (session.attempted) ...[
                  const SizedBox(height: AppSpace.lg),
                  _Feedback(session: session),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.lg,
            ),
            child: session.attempted
                ? PrimaryButton(
                    label: last ? 'Finish' : 'Next',
                    icon: last ? Icons.flag_rounded : Icons.arrow_forward,
                    onPressed: ctrl.next,
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CircleIconButton(
                            icon: Icons.volume_up_rounded,
                            size: 52,
                            tooltip: 'Hear it',
                            onTap: ctrl.playTarget,
                          ),
                          HaloMicButton(
                            icon: session.listening
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_rounded,
                            size: 100,
                            active: session.listening,
                            tooltip: 'Tap and speak',
                            onTap: session.listening ? null : ctrl.attempt,
                          ),
                          CircleIconButton(
                            icon: Icons.skip_next_rounded,
                            size: 52,
                            tooltip: 'Skip',
                            onTap: ctrl.next,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        session.listening ? 'Listening…' : 'Tap and speak',
                        style: TextStyle(
                          color: tones.inkSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.session});

  final SpeakingState session;

  /// A warm coaching line by score band — celebrate, encourage, never scold.
  static String _coachLine(double score) {
    if (score >= 0.85) return '¡Perfecto! That sounded great.';
    if (score >= 0.6) return '¡Muy bien! Really close to native.';
    if (score >= 0.35) return 'Getting there — give it one more go.';
    return 'Good try! Listen again and repeat slowly.';
  }

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final score = session.score ?? 0;
    final good = score >= 0.6;
    final tint = good ? AppTint.mint : AppTint.sun;
    final accent = tones.solid(tint);
    return SoftCard(
      tint: tint,
      padding: const EdgeInsets.all(AppSpace.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                good ? Icons.emoji_events_rounded : Icons.replay_rounded,
                color: accent,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  _coachLine(score),
                  style: TextStyle(
                    color: tones.onTint(tint),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              // Score counts up + pops in for a small win moment.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  '${(v * 100).round()}%',
                  style: TextStyle(
                    color: accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Heard: "${session.transcript}"',
            style: TextStyle(
              color: tones.onTint(tint).withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          if (session.words.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              'Word by word',
              style: TextStyle(
                color: tones.onTint(tint).withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm - 2,
              runSpacing: AppSpace.sm - 2,
              children: [
                for (final w in session.words)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tones.card.withValues(alpha: tones.dark ? 0.5 : 0.75),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          w.ok ? Icons.check_rounded : Icons.close_rounded,
                          size: 15,
                          color: w.ok
                              ? tones.solid(AppTint.mint)
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppSpace.xs + 1),
                        Text(
                          w.target,
                          style: TextStyle(
                            color: tones.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.session});

  final SpeakingState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FadeInUp(child: _Orb(size: 150)),
          const SizedBox(height: AppSpace.xl),
          Text(
            'Drills complete',
            style: TextStyle(
              color: tones.ink,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Your pronunciation confidence has been updated on the concepts '
            'you practiced.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tones.inkSoft, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: 'Practice again',
            icon: Icons.refresh_rounded,
            onPressed: () {
              final ctrl = ref.read(speakingProvider.notifier);
              ctrl.reset();
              ctrl.start();
            },
          ),
        ],
      ),
    );
  }
}
