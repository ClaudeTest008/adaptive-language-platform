import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/speech.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Voice settings (Phase 15): pick the speech engine and playback speed.
/// The choices live in session-persistent providers and flow through the
/// speech seam, so the rate is never hard-coded and the engine swaps with
/// no other UI change.
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  static const _speeds = [0.8, 0.9, 1.0, 1.1, 1.2];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final engine = ref.watch(speechEngineProvider);
    final speed = ref.watch(speechSpeedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                Text('Voice engine', style: text.titleMedium),
                const SizedBox(height: AppSpace.sm),
                _EngineOption(
                  value: SpeechEngine.piper,
                  selected: engine == SpeechEngine.piper,
                  title: 'Piper · offline neural',
                  subtitle:
                      'Free, on-device neural voice. Falls back to the device '
                      'voice until the Piper model is installed.',
                  onTap: () => ref.read(speechEngineProvider.notifier).state =
                      SpeechEngine.piper,
                ),
                const SizedBox(height: AppSpace.sm),
                _EngineOption(
                  value: SpeechEngine.androidNeural,
                  selected: engine == SpeechEngine.androidNeural,
                  title: 'Device TTS · fallback',
                  subtitle: 'The built-in Google/Samsung voice on this phone.',
                  onTap: () => ref.read(speechEngineProvider.notifier).state =
                      SpeechEngine.androidNeural,
                ),
                const SizedBox(height: AppSpace.xl),
                Text('Speech speed', style: text.titleMedium),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  children: [
                    for (final s in _speeds)
                      ChoiceChip(
                        label: Text('$s×'),
                        selected: (speed - s).abs() < 0.01,
                        onSelected: (_) =>
                            ref.read(speechSpeedProvider.notifier).state = s,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Test voice'),
                  onPressed: () => ref.read(speechServiceProvider).speak(
                        'Hola, soy tu profesor de español. ¡Vamos a aprender '
                        'juntos!',
                        langCode: ref.read(languageBcp47Provider),
                        speed: speed,
                      ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'The speed applies everywhere the tutor or a story speaks. '
                  'The reader also has its own player speed.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
