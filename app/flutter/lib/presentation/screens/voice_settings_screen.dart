import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../infrastructure/piper_speech_service.dart';
import '../../language/speech.dart';
import '../language_providers.dart';
import '../ui.dart';

/// The persisted Spanish Piper voice id (default claude-high). Applies on the
/// next app start: the Piper isolate loads exactly one model per process
/// (the ANR-fix invariant), so a live swap is deliberately not offered.
final piperEsVoiceProvider = FutureProvider<String>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(piperEsVoicePrefKey) ?? 'es_ES-sharvard-female';
  } catch (_) {
    return 'es_ES-sharvard-female';
  }
});

/// Voice settings (Phase 15): pick the speech engine and playback speed.
/// The choices live in session-persistent providers and flow through the
/// speech seam, so the rate is never hard-coded and the engine swaps with
/// no other UI change.
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  static const _speeds = [0.8, 0.9, 1.0, 1.1, 1.2];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final engine = ref.watch(speechEngineProvider);
    final speed = ref.watch(speechSpeedProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Voice settings'),
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.xl),
              children: [
                const SectionHeader(title: 'Voice engine'),
                const SizedBox(height: AppSpace.md),
                _EngineOption(
                  value: SpeechEngine.piper,
                  selected: engine == SpeechEngine.piper,
                  title: 'Piper · recommended',
                  subtitle: 'Offline neural voice (~60 MB download, no Google '
                      'dependency). The most natural Spanish in our ear tests.',
                  onTap: () => ref.read(speechEngineProvider.notifier).state =
                      SpeechEngine.piper,
                ),
                _EngineOption(
                  value: SpeechEngine.androidNeural,
                  selected: engine == SpeechEngine.androidNeural,
                  title: 'Device voice',
                  subtitle: "The phone's built-in voice (Google/Samsung). "
                      'Correct, but flatter than the offline voice.',
                  onTap: () => ref.read(speechEngineProvider.notifier).state =
                      SpeechEngine.androidNeural,
                ),
                const SizedBox(height: AppSpace.sm),
                if (engine == SpeechEngine.piper) ...[
                  const SizedBox(height: AppSpace.sm),
                  _PiperStatusCard(piper: ref.watch(piperSpeechProvider)),
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader(title: 'Spanish voice'),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Pronunciation quality differs per voice model — judge by '
                    'ear with "Test voice". A change applies the next time '
                    'the app starts (each voice is a separate ~60 MB '
                    'download).',
                    style: TextStyle(
                      color: tones.inkSoft,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Builder(builder: (context) {
                    final selected = ref.watch(piperEsVoiceProvider).value ??
                        'es_ES-sharvard-female';
                    return Column(
                      children: [
                        for (final e in piperSpanishVoices.entries) ...[
                          _EngineOption(
                            value: SpeechEngine.piper,
                            selected: selected == e.key,
                            title: e.value.label,
                            subtitle: e.key,
                            onTap: () async {
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                    piperEsVoicePrefKey, e.key);
                              } catch (_) {}
                              ref.invalidate(piperEsVoiceProvider);
                            },
                          ),
                          const SizedBox(height: AppSpace.sm),
                        ],
                      ],
                    );
                  }),
                ],
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Speech speed'),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final s in _speeds)
                      SoftChip(
                        label: '$s×',
                        icon: (speed - s).abs() < 0.01
                            ? Icons.check_rounded
                            : null,
                        tint: AppTint.mint,
                        muted: (speed - s).abs() >= 0.01,
                        onTap: () =>
                            ref.read(speechSpeedProvider.notifier).state = s,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: 'Test voice',
                  icon: Icons.volume_up_rounded,
                  // The sample covers every sound the ear tests flagged or
                  // watch-list: vaya, llegó, llevar, lluvia, yo, ll, rr, ñ —
                  // one tap A/Bs a whole voice.
                  onPressed: () => ref.read(speechServiceProvider).speak(
                        '¡Vaya! Ayer llegó la lluvia y yo quiero llevar el '
                        'paraguas por la calle. El perro corre rápido. '
                        'Mañana el joven trabaja, juega y viaja con su hijo. '
                        'La mujer dijo que el jamón del viaje es mejor.',
                        langCode: ref.read(languageBcp47Provider),
                        speed: speed,
                      ),
                ),
                const SizedBox(height: AppSpace.xl),
                // Phase 23: offline speech understanding (Whisper).
                _SettingsLink(
                  icon: Icons.hearing,
                  title: 'Offline speech (Whisper)',
                  subtitle: 'Understand your speech on-device',
                  onTap: () => context.push('/whisper-settings'),
                ),
                const SizedBox(height: AppSpace.sm),
                // Phase 25: optional on-device LLM (natural wording).
                _SettingsLink(
                  icon: Icons.smart_toy_outlined,
                  title: 'On-device teacher voice (LLM)',
                  subtitle: 'Optional — more natural wording',
                  onTap: () => context.push('/llm-settings'),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'The speed applies everywhere the tutor or a story speaks. '
                  'The reader also has its own player speed.',
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live Piper voice status: idle → tap to download → progress bar →
/// extracting → loading → ready. Rebuilds off the service's notifiers.
class _PiperStatusCard extends ConsumerWidget {
  const _PiperStatusCard({required this.piper});

  final PiperSpeechService piper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge(
        [piper.status, piper.progress, piper.statusDetail],
      ),
      builder: (context, _) {
        final s = piper.status.value;
        final (icon, label) = switch (s) {
          PiperStatus.idle => (
              Icons.download_rounded,
              'Neural voice not installed yet — download ~60 MB',
            ),
          PiperStatus.downloading => (
              Icons.downloading_rounded,
              'Downloading… ${(piper.progress.value * 100).round()}%',
            ),
          PiperStatus.extracting => (Icons.archive_rounded, 'Unpacking voice…'),
          PiperStatus.loading => (Icons.memory_rounded, 'Loading model…'),
          PiperStatus.ready => (Icons.check_circle_rounded, 'Piper voice ready'),
          PiperStatus.error => (Icons.error_rounded, piper.statusDetail.value),
        };
        return SoftCard(
          elevated: false,
          radius: AppRadius.tile,
          padding: const EdgeInsets.all(AppSpace.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconChip(
                    icon: icon,
                    color: s == PiperStatus.error
                        ? Theme.of(context).colorScheme.error
                        : tones.solid(AppTint.mint),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tones.inkSoft, fontSize: 13.5),
                    ),
                  ),
                  if (s == PiperStatus.idle || s == PiperStatus.error)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: tones.ink,
                      ),
                      onPressed: () => piper
                          .ensureVoice(ref.read(languageBcp47Provider)),
                      child: const Text('Download'),
                    ),
                ],
              ),
              if (s == PiperStatus.downloading) ...[
                const SizedBox(height: AppSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: piper.progress.value == 0
                        ? null
                        : piper.progress.value,
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EngineOption extends StatelessWidget {
  const _EngineOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final SpeechEngine value;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final fg = selected ? tones.onTint(AppTint.mint) : tones.ink;
    return SoftCard(
      tint: selected ? AppTint.mint : null,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? tones.solid(AppTint.mint) : tones.inkSoft,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: AppSpace.xs - 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected ? fg.withValues(alpha: 0.8) : tones.inkSoft,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular icon chip used by every status/link row in settings.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

/// Navigation row into a sub-settings screen.
class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          _IconChip(icon: icon, color: tones.solid(AppTint.lilac)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tones.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Icon(Icons.chevron_right, color: tones.inkSoft),
        ],
      ),
    );
  }
}
