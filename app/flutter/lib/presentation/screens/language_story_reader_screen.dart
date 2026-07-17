import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/story.dart';
import '../language_providers.dart';
import '../reading_state.dart';
import '../ui.dart';
import 'home_shell.dart';
import 'reader_companion.dart';

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

/// Kindle-style reading mode: show the target language, both, or the
/// translation only. The translation always stays visually secondary.
enum _ReaderMode { both, spanish, english }

class _LanguageStoryReaderScreenState
    extends ConsumerState<LanguageStoryReaderScreen> {
  late int _phrase = lastReadingPage(widget.storyId);
  bool _showQuiz = false;
  bool _showComplete = false;
  bool _playing = false;
  late bool _bookmarked = isBookmarked(widget.storyId);
  double _speed = 1.0;
  _ReaderMode _mode = _ReaderMode.both;
  late final PageController _pageController =
      PageController(initialPage: _phrase);

  @override
  void dispose() {
    _pageController.dispose();
    ref.read(speechServiceProvider).stop();
    super.dispose();
  }

  Future<void> _playParagraph(String text, String bcp47) async {
    final speech = ref.read(speechServiceProvider);
    await speech.stop();
    setState(() => _playing = true);
    await speech.speak(text, langCode: bcp47, speed: _speed);
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _stopAudio() async {
    await ref.read(speechServiceProvider).stop();
    if (mounted) setState(() => _playing = false);
  }

  void _cycleSpeed() {
    const speeds = [0.8, 1.0, 1.2, 1.5];
    final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    setState(() => _speed = next);
  }

  /// Reading Companion — ask questions about the current page without
  /// leaving the book. Reuses the tutor's AiChatModel seam.
  void _showCompanion(BuildContext context, Story story) {
    final page = story.phrases[_phrase.clamp(0, story.phrases.length - 1)];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReadingCompanionSheet(story: story, paragraph: page.text),
      ),
    );
  }

  /// Key-words glossary as a bottom sheet.
  void _showVocab(BuildContext context, Story story) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            AppSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Key words', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              for (final v in story.vocabulary)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          v.word,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          v.meaning,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
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

    final bcp47 = ref.watch(languageBcp47Provider);
    final speech = ref.read(speechServiceProvider);
    final isLast = _phrase + 1 >= story.phrases.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(story.title),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            tooltip: 'Bookmark',
            onPressed: () {
              toggleBookmark(widget.storyId);
              setState(() => _bookmarked = isBookmarked(widget.storyId));
            },
          ),
          if (story.vocabulary.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Key words',
              onPressed: () => _showVocab(context, story),
            ),
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Reading companion',
            onPressed: () => _showCompanion(context, story),
          ),
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
            child: _showQuiz
                ? _Quiz(
                    story: story,
                    onFinish: () => Navigator.of(context).pop(),
                  )
                : _showComplete
                    ? CompletionCard(
                        story: story,
                        onContinue: () => Navigator.of(context).pop(),
                        onCompanion: () => _showCompanion(context, story),
                        onVocab: story.vocabulary.isEmpty
                            ? null
                            : () => _showVocab(context, story),
                        onSpeaking: () {
                          ref.read(homeTabProvider.notifier).state = 2;
                          Navigator.of(context).pop();
                        },
                        onQuiz: story.questions.isEmpty
                            ? null
                            : () => setState(() {
                                  _showComplete = false;
                                  _showQuiz = true;
                                }),
                      )
                    : Column(
                    children: [
                      // Slim reading progress + page counter.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl,
                          AppSpace.lg,
                          AppSpace.xl,
                          0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: (_phrase + 1) / story.phrases.length,
                                  ),
                                  duration: const Duration(milliseconds: 320),
                                  curve: AppMotion.curve,
                                  builder: (context, v, _) =>
                                      LinearProgressIndicator(
                                    value: v,
                                    minHeight: 5,
                                    backgroundColor:
                                        scheme.onSurface.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Text(
                              '${_phrase + 1} / ${story.phrases.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      // Kindle-style display toggle.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl,
                          AppSpace.md,
                          AppSpace.xl,
                          0,
                        ),
                        child: SegmentedButton<_ReaderMode>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: _ReaderMode.spanish,
                              label: Text('Español'),
                            ),
                            ButtonSegment(
                              value: _ReaderMode.both,
                              label: Text('Both'),
                            ),
                            ButtonSegment(
                              value: _ReaderMode.english,
                              label: Text('English'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (s) =>
                              setState(() => _mode = s.first),
                        ),
                      ),
                      // Swipeable story pages — book-like reading with the
                      // target language large and the translation secondary.
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: story.phrases.length,
                          onPageChanged: (i) {
                            ref.read(speechServiceProvider).stop();
                            saveReadingPage(widget.storyId, i);
                            setState(() {
                              _phrase = i;
                              _playing = false;
                            });
                          },
                          itemBuilder: (context, i) {
                            final p = story.phrases[i];
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpace.xl,
                                AppSpace.xxl,
                                AppSpace.xl,
                                AppSpace.xl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (story.hasChapters) ...[
                                    Text(
                                      'Capítulo ${story.chapterOf(i) + 1} · '
                                      '${story.chapterTitles[story.chapterOf(i)]}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                  ],
                                  if (_mode != _ReaderMode.english)
                                    Text(
                                      p.text,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        height: 1.55,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  if (_mode == _ReaderMode.both) ...[
                                    const SizedBox(height: AppSpace.xl),
                                    Divider(
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: AppSpace.lg),
                                  ],
                                  if (_mode != _ReaderMode.spanish)
                                    Text(
                                    p.translation,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.85),
                                          height: 1.5,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Audiobook player: play / pause / stop, paragraph
                      // skip, and playback speed. Stop always halts at once.
                      if (speech.available)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.xl,
                            0,
                            AppSpace.xl,
                            AppSpace.md,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.xs,
                              vertical: AppSpace.xs,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded),
                                  tooltip: 'Previous paragraph',
                                  onPressed: _phrase == 0
                                      ? null
                                      : () => _pageController.previousPage(
                                            duration: const Duration(
                                                milliseconds: 320),
                                            curve: AppMotion.curve,
                                          ),
                                ),
                                IconButton.filled(
                                  icon: Icon(
                                    _playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                  tooltip: _playing ? 'Pause' : 'Play',
                                  onPressed: () {
                                    if (_playing) {
                                      ref
                                          .read(speechServiceProvider)
                                          .pause();
                                      setState(() => _playing = false);
                                    } else {
                                      _playParagraph(
                                        story.phrases[_phrase].text,
                                        bcp47,
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.stop_rounded),
                                  tooltip: 'Stop',
                                  onPressed: _stopAudio,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded),
                                  tooltip: 'Next paragraph',
                                  onPressed: isLast
                                      ? null
                                      : () => _pageController.nextPage(
                                            duration: const Duration(
                                                milliseconds: 320),
                                            curve: AppMotion.curve,
                                          ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _cycleSpeed,
                                  child: Text('${_speed}x'),
                                ),
                                const SizedBox(width: AppSpace.xs),
                              ],
                            ),
                          ),
                        ),
                      // Reading controls.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl,
                          0,
                          AppSpace.xl,
                          AppSpace.xl,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _phrase == 0
                                    ? null
                                    : () => _pageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 320,
                                          ),
                                          curve: AppMotion.curve,
                                        ),
                                child: const Text('Back'),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                icon: Icon(
                                  isLast
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                ),
                                label: Text(isLast ? 'Finish' : 'Continue'),
                                onPressed: () {
                                  if (!isLast) {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 320),
                                      curve: AppMotion.curve,
                                    );
                                  } else {
                                    // No forced quiz — show a completion card;
                                    // the quiz is one optional choice on it.
                                    ref.read(speechServiceProvider).stop();
                                    setState(() => _showComplete = true);
                                  }
                                },
                              ),
                            ),
                          ],
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

/// Comprehension quiz shown after the reading: each question reveals the
/// correct answer once tapped; a running score sits at the top.
class _Quiz extends StatefulWidget {
  const _Quiz({required this.story, required this.onFinish});

  final Story story;
  final VoidCallback onFinish;

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  final Map<int, int> _picked = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final questions = widget.story.questions;
    final correct = [
      for (final e in _picked.entries)
        if (questions[e.key].answerIndex == e.value) e,
    ].length;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        Text(
          'Comprehension',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          '$correct / ${questions.length} correct',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpace.lg),
        for (final (qi, q) in questions.indexed)
          FadeInUp(
            delayMs: qi * 60,
            child: GlassCard(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.prompt,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpace.md),
                  for (final (oi, opt) in q.options.indexed)
                    _Option(
                      label: opt,
                      state: _picked[qi] == null
                          ? _OptState.idle
                          : oi == q.answerIndex
                              ? _OptState.correct
                              : (_picked[qi] == oi
                                  ? _OptState.wrong
                                  : _OptState.idle),
                      onTap: _picked.containsKey(qi)
                          ? null
                          : () => setState(() => _picked[qi] = oi),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Finish'),
          onPressed: widget.onFinish,
        ),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }
}

enum _OptState { idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.state, this.onTap});

  final String label;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (state) {
      _OptState.correct => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.check_circle,
        ),
      _OptState.wrong => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.cancel,
        ),
      _OptState.idle => (scheme.surfaceContainerHighest, scheme.onSurface, null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(color: fg)),
                ),
                if (icon != null) Icon(icon, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
