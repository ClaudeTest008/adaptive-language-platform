/// Shared premium UI kit: one place for the spacing scale, the palette that
/// the design mockups specify, the card/chip/button chrome and the entrance
/// motion, so every learner surface belongs to one design system.
///
/// Pure presentation — no logic, no core imports. Both brightnesses are
/// first-class: every token resolves through [AppTones.of], so a widget is
/// written once and reads correctly in light and dark.
library;

import 'dart:ui';

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

/// Corner radii — the mockups use generously rounded cards, softer inputs
/// and fully-round pills.
abstract final class AppRadius {
  static const double card = 24;
  static const double tile = 20;
  static const double input = 18;
  static const double pill = 999;
}

/// Entrance motion timing — calm, quick, never showy.
abstract final class AppMotion {
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration quick = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOutCubic;
}

/// The four accent tints from the design: each is a soft filled card in
/// light mode and a muted, deeper wash in dark mode.
enum AppTint { sage, sun, mint, lilac, ink }

/// Brightness-resolved design tokens. Read once per build:
/// `final tones = AppTones.of(context);`
class AppTones {
  const AppTones._({
    required this.dark,
    required this.canvas,
    required this.canvasTop,
    required this.card,
    required this.cardMuted,
    required this.ink,
    required this.inkSoft,
    required this.hairline,
    required this.accent,
    required this.onAccent,
  });

  final bool dark;

  /// Page background.
  final Color canvas;

  /// Warmer wash used at the top of hero areas.
  final Color canvasTop;

  /// Primary raised surface (message bubbles, content cards).
  final Color card;

  /// Recessed surface (chips, inactive circle buttons, input fills).
  final Color cardMuted;

  /// Primary text / high-contrast button fill.
  final Color ink;

  /// Secondary text.
  final Color inkSoft;

  /// Hairline divider / border.
  final Color hairline;

  /// The one brand accent (dark navy in light, warm yellow in dark).
  final Color accent;
  final Color onAccent;

  static const _lightTones = AppTones._(
    dark: false,
    canvas: Color(0xFFF7F3E9),
    canvasTop: Color(0xFFFDF7EE),
    card: Color(0xFFFFFFFF),
    cardMuted: Color(0xFFEDE8DC),
    ink: Color(0xFF1B1E28),
    inkSoft: Color(0xFF6B6E7A),
    hairline: Color(0x14000000),
    accent: Color(0xFF1B1E28),
    onAccent: Color(0xFFFFFFFF),
  );

  static const _darkTones = AppTones._(
    dark: true,
    canvas: Color(0xFF111217),
    canvasTop: Color(0xFF171921),
    card: Color(0xFF1E212A),
    cardMuted: Color(0xFF262A34),
    ink: Color(0xFFF4F5F7),
    inkSoft: Color(0xFF9AA0AE),
    hairline: Color(0x1FFFFFFF),
    accent: Color(0xFFF5CE47),
    onAccent: Color(0xFF1B1E28),
  );

  static AppTones of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkTones : _lightTones;

  /// Background fill for a tinted card.
  Color tint(AppTint t) => switch (t) {
        AppTint.sage => dark ? const Color(0xFF2C3327) : const Color(0xFFDCDCC0),
        AppTint.sun => dark ? const Color(0xFF3A331C) : const Color(0xFFF7D64B),
        AppTint.mint => dark ? const Color(0xFF1F3330) : const Color(0xFFC9E2D6),
        AppTint.lilac => dark ? const Color(0xFF272741) : const Color(0xFFC3C4F7),
        AppTint.ink => dark ? const Color(0xFF262A34) : ink,
      };

  /// Foreground for content sitting on [tint].
  Color onTint(AppTint t) => switch (t) {
        AppTint.ink => dark ? ink : const Color(0xFFFFFFFF),
        _ => dark ? const Color(0xFFEDEFF3) : const Color(0xFF1B1E28),
      };

  /// The one card shadow in the system. Dark mode uses none (elevation reads
  /// as surface tint there), so every raised surface asks for this instead of
  /// hand-rolling its own alpha.
  List<BoxShadow>? get cardShadow => dark
      ? null
      : const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ];

  /// A tighter shadow for small raised elements (chat bubbles, covers).
  List<BoxShadow>? get softShadow => dark
      ? null
      : const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ];

  /// The saturated version of a tint — icon strokes, progress, glows.
  Color solid(AppTint t) => switch (t) {
        AppTint.sage => const Color(0xFF7C8B5A),
        AppTint.sun => const Color(0xFFE0AE12),
        AppTint.mint => const Color(0xFF2E9E74),
        AppTint.lilac => const Color(0xFF6C6CE5),
        AppTint.ink => accent,
      };
}

/// The page backdrop from the mockups: a soft warm-to-canvas vertical wash.
/// Replaces the previous glow-heavy backdrop while keeping the same API, so
/// every screen that already wraps its body keeps working.
class AtmosphericBackground extends StatelessWidget {
  const AtmosphericBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.45, 1],
                colors: [tones.canvasTop, tones.canvas, tones.canvas],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A soft-filled content card — the default surface of the design system.
/// [tint] fills it with one of the four accents; omit for the neutral card.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.radius = AppRadius.card,
    this.elevated = true,
  });

  final Widget child;
  final AppTint? tint;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final fill = tint == null ? tones.card : tones.tint(tint!);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? tones.cardShadow : null,
      ),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The 2×2 grid tile from the home mockup: a small icon chip with a label on
/// top, the action title below, and a trailing arrow on the baseline.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.title,
    required this.tint,
    this.onTap,
  });

  final IconData icon;

  /// Small caption beside the icon chip (e.g. "Voice").
  final String label;

  /// The action itself (e.g. "Try voice recognition").
  final String title;
  final AppTint tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final fg = tones.onTint(tint);
    return SoftCard(
      tint: tint,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: AppSpace.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Spacer, not a fixed gap: the tile keeps its shape when the title
          // wraps or the user runs a larger text scale.
          const Spacer(),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Icon(Icons.arrow_forward, size: 18, color: fg),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular icon button — the recurring chrome of the mockups (app-bar
/// actions, the flanking tutor controls). [filled] gives it the accent fill.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 46,
    this.filled = false,
    this.color,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool filled;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final bg = color ?? (filled ? tones.accent : tones.cardMuted);
    final fg = foreground ?? (filled ? tones.onAccent : tones.ink);
    final button = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.44, color: fg),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Status pill — the stacked chips on the tutor mockup. Optional leading
/// icon, optional accent [tint] for the icon, [muted] for a quieter state.
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    this.icon,
    this.tint,
    this.muted = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final AppTint? tint;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final fg = muted ? tones.inkSoft : tones.ink;
    return Material(
      color: tones.cardMuted.withValues(alpha: tones.dark ? 1 : 0.75),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md + 2,
            vertical: AppSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: tint == null ? fg : tones.solid(tint!),
                ),
                const SizedBox(width: AppSpace.sm - 2),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
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

/// Section title with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: tones.ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: tones.inkSoft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// Full-width primary button in the mockup's shape (tall, softly rounded).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Fill override; defaults to the accent (dark ink in light mode).
  final AppTint? tint;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final bg = tint == null ? tones.accent : tones.tint(tint!);
    final fg = tint == null ? tones.onAccent : tones.onTint(tint!);
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: AppSpace.sm),
              Icon(icon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// The big circular mic from the tutor/speaking mockups: concentric halo
/// rings that breathe while [active], a solid core, tactile press.
class HaloMicButton extends StatefulWidget {
  const HaloMicButton({
    super.key,
    required this.icon,
    this.active = false,
    this.color,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.size = 92,
    this.tooltip,
  });

  final IconData icon;

  /// Pulses the halo (listening / speaking).
  final bool active;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final double size;
  final String? tooltip;

  @override
  State<HaloMicButton> createState() => _HaloMicButtonState();
}

class _HaloMicButtonState extends State<HaloMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HaloMicButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final accent = widget.color ?? tones.solid(AppTint.mint);
    final core = widget.size * 0.62;
    final button = GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onLongPressStart: widget.onLongPressStart == null
          ? null
          : (_) {
              setState(() => _down = true);
              widget.onLongPressStart!();
            },
      onLongPressEnd: widget.onLongPressEnd == null
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onLongPressEnd!();
            },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = widget.active ? _pulse.value : 0.0;
          return AnimatedScale(
            scale: _down ? 0.94 : 1,
            duration: AppMotion.quick,
            curve: Curves.easeOut,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer halo — grows and fades as it breathes.
                  Container(
                    width: widget.size * (0.86 + 0.14 * t),
                    height: widget.size * (0.86 + 0.14 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(
                        alpha: (widget.active ? 0.26 : 0.14) * (1 - 0.4 * t),
                      ),
                    ),
                  ),
                  // Inner ring.
                  Container(
                    width: widget.size * 0.76,
                    height: widget.size * 0.76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                  ),
                  // Core.
                  Container(
                    width: core,
                    height: core,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.active ? accent : tones.cardMuted,
                      boxShadow: widget.active
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      widget.icon,
                      size: core * 0.45,
                      color: widget.active
                          ? (tones.dark ? const Color(0xFF10131A) : Colors.white)
                          : tones.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
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
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Kept for the surfaces that already compose with them. Restyled to the new
// palette so they read as part of the same system.
// ---------------------------------------------------------------------------

/// Gradient hero card — used where a surface needs to lead the page.
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
    final tones = AppTones.of(context);
    final grad = colors ??
        (tones.dark
            ? [const Color(0xFF232734), const Color(0xFF1C1F28)]
            : [const Color(0xFFFDF2DE), const Color(0xFFF3EDDF)]);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: tones.cardShadow,
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
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass surface — translucent fill over a backdrop blur.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.blur = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tones.card.withValues(alpha: tones.dark ? 0.72 : 0.86),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: tones.hairline),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
