/// Shared premium UI kit (Phase 9): one place for the spacing scale, the
/// gradient hero chrome, frosted pills and the entrance motion so every
/// learner surface feels consistent. Pure presentation — no logic, no core.
library;

import 'package:flutter/material.dart';

/// 4-based spacing scale. Use instead of ad-hoc SizedBox magic numbers.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii — cards are softer than inputs, pills fully round.
abstract final class AppRadius {
  static const double card = 20;
  static const double input = 16;
  static const double pill = 999;
}

/// Entrance motion timing — calm, quick, never showy.
abstract final class AppMotion {
  static const Duration enter = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
}

/// Gradient hero card with soft depth and a subtle top-left glass sheen —
/// the recurring "hero" chrome (dashboard header, tutor heroes). Pass the
/// content as [child]; the gradient defaults to the M3 container ramp.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.child,
    this.colors,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.xl),
  });

  final Widget child;
  final List<Color>? colors;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grad = colors ??
        [
          scheme.primaryContainer,
          scheme.tertiaryContainer,
          scheme.secondaryContainer,
        ];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: grad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Soft diagonal sheen for a glass-lit feel.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted translucent pill for use on gradient heroes.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A gentle fade-and-rise entrance. [delayMs] staggers siblings via a curve
/// interval (no timers), so a list can cascade in. Settles well within a
/// test's pump budget.
class FadeInUp extends StatelessWidget {
  const FadeInUp({super.key, this.delayMs = 0, required this.child});

  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = AppMotion.enter.inMilliseconds + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: AppMotion.curve),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}
