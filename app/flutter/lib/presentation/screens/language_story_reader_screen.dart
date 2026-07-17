import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../language_providers.dart';
import '../ui.dart';

/// Story reader (ADR-0020): one bite-sized phrase on screen at a time,
/// target text large with the native translation beneath, a Listen button
/// (text-to-speech) per phrase and for the whole story.
class LanguageStoryReaderScreen extends ConsumerStatefulWidget {
  const LanguageStoryReaderScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<LanguageStoryReaderScreen> createState() =>
      _LanguageStoryReaderScreenState();
}

class _LanguageStoryReaderScreenState
    extends ConsumerState<LanguageStoryReaderScreen> {
  int _phrase = 0;

  @override
  void dispose() {
    ref.read(speechServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(storiesProvider);
    final scheme = Theme.of(context).colorScheme;

    final story = storiesAsync.value
        ?.where((s) => s.id == widget.storyId)
        .firstOrNull;
    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Story')),
        body: Center(
          child: Text(storiesAsync.isLoading ? 'Loading…' : 'Story not found'),
        ),
      );
    }

    final phrase = story.phrases[_phrase];
    final bcp47 = ref.watch(languageBcp47Provider);
    final speech = ref.read(speechServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(story.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.headphones),
            tooltip: 'Listen to the whole story',
            onPressed: () => speech.speak(story.fullText, langCode: bcp47),
          ),
        ],
      ),
      body: AtmosphericBackground(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_phrase + 1) / story.phrases.length,
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  'Phrase ${_phrase + 1} of ${story.phrases.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                FadeInUp(
                  key: ValueKey(_phrase),
                  child: Card(
                  color: scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Text(
                          phrase.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Divider(color: scheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          phrase.translation,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Listen'),
                          onPressed: () =>
                              speech.speak(phrase.text, langCode: bcp47),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        onPressed: _phrase == 0
                            ? null
                            : () => setState(() => _phrase--),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(
                          _phrase + 1 < story.phrases.length
                              ? Icons.arrow_forward
                              : Icons.check,
                        ),
                        label: Text(
                          _phrase + 1 < story.phrases.length ? 'Next' : 'Done',
                        ),
                        onPressed: () {
                          if (_phrase + 1 < story.phrases.length) {
                            setState(() => _phrase++);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ],
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
