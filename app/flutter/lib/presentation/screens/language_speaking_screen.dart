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
        backgroundColor: Colors.transparent,
        title: const Text('Speaking'),
        actions: [
          if (session != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'End',
              onPressed: () => ref.read(speakingProvider.notifier).reset(),
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

class _Intro extends ConsumerWidget {
  const _Intro({required this.speechAvailable});

  final bool speechAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInUp(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.record_voice_over,
                size: 56,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            'Speaking practice',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Hear a word or phrase, say it aloud, and get a pronunciation '
            'score. Your weakest concepts come first.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!speechAvailable) ...[
            const SizedBox(height: 12),
            Text(
              'Voice is unavailable on this device/browser — you can still '
              'run the drills.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start drills'),
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
    final scheme = Theme.of(context).colorScheme;
    final drill = session.current;
    final ctrl = ref.read(speakingProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (session.index + 1) / session.drills.length,
            minHeight: 6,
          ),
          const Spacer(),
          Text('Say this aloud',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Card(
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(
                    drill.target,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (drill.translation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      drill.translation!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Hear it'),
                    onPressed: ctrl.playTarget,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (session.attempted) _Feedback(session: session) else
            _MicButton(listening: session.listening, onTap: ctrl.attempt),
          const Spacer(),
          if (session.attempted)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(
                  session.index + 1 < session.drills.length
                      ? Icons.arrow_forward
                      : Icons.flag,
                ),
                label: Text(
                  session.index + 1 < session.drills.length
                      ? 'Next'
                      : 'Finish',
                ),
                onPressed: ctrl.next,
              ),
            ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        GestureDetector(
          onTap: listening ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: listening ? scheme.error : scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              listening ? Icons.hearing : Icons.mic,
              color: scheme.onPrimary,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(listening ? 'Listening…' : 'Tap and speak'),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.session});

  final SpeakingState session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = session.score ?? 0;
    final good = score >= 0.6;
    final color = good ? scheme.primary : scheme.error;
    return Card(
      color: good
          ? scheme.primaryContainer
          : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(good ? Icons.check_circle : Icons.replay, color: color),
                const SizedBox(width: 8),
                Text(
                  good ? 'Nicely said!' : 'Keep practicing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text('${(score * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Heard: "${session.transcript}"'),
            ),
            if (session.words.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Word by word',
                    style: Theme.of(context).textTheme.labelMedium),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in session.words)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        w.ok ? Icons.check : Icons.close,
                        size: 16,
                        color: w.ok ? Colors.green : scheme.error,
                      ),
                      label: Text(w.target),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.session});

  final SpeakingState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Drills complete',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your pronunciation confidence has been updated on the concepts '
            'you practiced.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Practice again'),
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
