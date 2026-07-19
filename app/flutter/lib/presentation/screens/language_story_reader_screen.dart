import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/piper_speech_service.dart';
import '../../language/pipeline.dart';
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

  // Phase 35/38 session instrumentation — real measurements only. The clock
  // lives in the UI layer; every engine downstream takes these as inputs.
  final DateTime _sessionStart = DateTime.now();
  int _pauses = 0;
  int _replays = 0;
  int _revisits = 0;
  int _wordTaps = 0;
  final Set<int> _played = {};
  late final Set<int> _visited = {_phrase};

  @override
  void dispose() {
    _pageController.dispose();
    ref.read(speechServiceProvider).stop();
    super.dispose();
  }

  bool _prefetched = false;

  /// Phase 28: warm the Piper cache for the current + next page in the
  /// background, so pressing Play (or turning the page) is instant. Best-effort
  /// and Piper-only; no-op for the device fallback or in tests.
  void _prefetchAround(Story story, int i) {
    final speech = ref.read(speechServiceProvider);
    if (speech is! PiperSpeechService) return;
    final texts = <String>[
      for (var k = i; k <= i + 1 && k < story.phrases.length; k++)
        story.phrases[k].text,
    ];
    if (texts.isEmpty) return;
    speech.prefetch(
      texts,
      langCode: ref.read(languageBcp47Provider),
      speed: _speed,
    );
  }

  Future<void> _playParagraph(String text, String bcp47) async {
    if (!_played.add(_phrase)) _replays++; // measured: replay of a heard page
    final speech = ref.read(speechServiceProvider);
    await speech.stop();
    setState(() => _playing = true);
    await speech.speak(text, langCode: bcp47, speed: _speed);
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _stopAudio() async {
    if (_playing) _pauses++; // measured: learner interrupted playback
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
      backgroundColor: AppTones.of(context).canvasTop,
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
      backgroundColor: AppTones.of(context).canvasTop,
      builder: (context) {
        final tones = AppTones.of(context);
        return SafeArea(
          child: SingleChildScrollView(
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
                Text(
                  'Key words',
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                for (final v in story.vocabulary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: SoftCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg,
                        vertical: AppSpace.md,
                      ),
                      radius: AppRadius.input,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              v.word,
                              style: TextStyle(
                                color: tones.ink,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              v.meaning,
                              style: TextStyle(
                                color: tones.inkSoft,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(storiesProvider);
    final tones = AppTones.of(context);

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

    // Prefetch audio for the opening page once the story is loaded.
    if (!_prefetched) {
      _prefetched = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _prefetchAround(story, _phrase));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(story.title),
        actions: [
          CircleIconButton(
            icon: _bookmarked ? Icons.bookmark : Icons.bookmark_border,
            tooltip: 'Bookmark',
            size: 42,
            filled: _bookmarked,
            onTap: () {
              toggleBookmark(widget.storyId);
              setState(() => _bookmarked = isBookmarked(widget.storyId));
            },
          ),
          if (story.vocabulary.isNotEmpty) ...[
            const SizedBox(width: AppSpace.sm - 2),
            CircleIconButton(
              icon: Icons.menu_book_outlined,
              tooltip: 'Key words',
              size: 42,
              onTap: () => _showVocab(context, story),
            ),
          ],
          const SizedBox(width: AppSpace.sm - 2),
          CircleIconButton(
            icon: Icons.forum_outlined,
            tooltip: 'Reading companion',
            size: 42,
            onTap: () => _showCompanion(context, story),
          ),
          const SizedBox(width: AppSpace.sm - 2),
          CircleIconButton(
            icon: Icons.headphones,
            tooltip: 'Listen to the whole story',
            size: 42,
            onTap: () => speech.speak(story.fullText, langCode: bcp47),
          ),
          const SizedBox(width: AppSpace.md),
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
                                    color: tones.solid(AppTint.mint),
                                    backgroundColor: tones.cardMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Text(
                              '${_phrase + 1} / ${story.phrases.length}',
                              style: TextStyle(
                                color: tones.inkSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            side: WidgetStatePropertyAll(
                              BorderSide(color: tones.hairline),
                            ),
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) =>
                                    states.contains(WidgetState.selected)
                                        ? tones.accent
                                        : tones.cardMuted),
                            foregroundColor:
                                WidgetStateProperty.resolveWith((states) =>
                                    states.contains(WidgetState.selected)
                                        ? tones.onAccent
                                        : tones.ink),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
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
                            if (!_visited.add(i)) _revisits++; // measured
                            ref.read(speechServiceProvider).stop();
                            saveReadingPage(widget.storyId, i);
                            setState(() {
                              _phrase = i;
                              _playing = false;
                            });
                            _prefetchAround(story, i);
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tones.solid(AppTint.mint),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.lg),
                                  ],
                                  if (_mode != _ReaderMode.english)
                                    // Phase 21: every word is long-pressable —
                                    // the teacher explains it through
                                    // connections, dictionary second.
                                    _TappableTargetText(
                                      text: p.text,
                                      onWordTap: () => _wordTaps++,
                                    ),
                                  if (_mode == _ReaderMode.both) ...[
                                    const SizedBox(height: AppSpace.xl),
                                    Divider(color: tones.hairline),
                                    const SizedBox(height: AppSpace.lg),
                                  ],
                                  if (_mode != _ReaderMode.spanish)
                                    Text(
                                      p.translation,
                                      style: TextStyle(
                                        color: tones.inkSoft,
                                        fontSize: 16.5,
                                        height: 1.6,
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
                              horizontal: AppSpace.sm,
                              vertical: AppSpace.sm,
                            ),
                            decoration: BoxDecoration(
                              color: tones.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: tones.hairline),
                            ),
                            child: Row(
                              children: [
                                CircleIconButton(
                                  icon: Icons.skip_previous_rounded,
                                  tooltip: 'Previous paragraph',
                                  size: 42,
                                  onTap: _phrase == 0
                                      ? null
                                      : () => _pageController.previousPage(
                                            duration: const Duration(
                                                milliseconds: 320),
                                            curve: AppMotion.curve,
                                          ),
                                ),
                                const SizedBox(width: AppSpace.sm - 2),
                                CircleIconButton(
                                  icon: _playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  tooltip: _playing ? 'Pause' : 'Play',
                                  size: 48,
                                  filled: true,
                                  onTap: () {
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
                                const SizedBox(width: AppSpace.sm - 2),
                                CircleIconButton(
                                  icon: Icons.stop_rounded,
                                  tooltip: 'Stop',
                                  size: 42,
                                  onTap: _stopAudio,
                                ),
                                const SizedBox(width: AppSpace.sm - 2),
                                CircleIconButton(
                                  icon: Icons.skip_next_rounded,
                                  tooltip: 'Next paragraph',
                                  size: 42,
                                  onTap: isLast
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
                                  style: TextButton.styleFrom(
                                    foregroundColor: tones.inkSoft,
                                    minimumSize: const Size(0, 36),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    '${_speed}x',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
                              child: SizedBox(
                                height: 58,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: tones.ink,
                                    side: BorderSide(color: tones.hairline),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.pill),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                icon: isLast
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                label: isLast ? 'Finish' : 'Continue',
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
                                    // Phase 22 producer: a finished story
                                    // becomes a measured reading record
                                    // (vocab mined, interests discovered).
                                    ref
                                        .read(readingExperienceProvider.notifier)
                                        .recordCompletion(
                                          story,
                                          durationMs: DateTime.now()
                                              .difference(_sessionStart)
                                              .inMilliseconds,
                                          pauseCount: _pauses,
                                          replays: _replays,
                                          pagesRevisited: _revisits,
                                          wordTaps: _wordTaps,
                                        );
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
    final tones = AppTones.of(context);
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
          style: TextStyle(
            color: tones.ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: SoftChip(label: '$correct / ${questions.length} correct'),
        ),
        const SizedBox(height: AppSpace.lg),
        for (final (qi, q) in questions.indexed)
          FadeInUp(
            delayMs: qi * 60,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: SoftCard(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.prompt,
                      style: TextStyle(
                        color: tones.ink,
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
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
          ),
        const SizedBox(height: AppSpace.sm),
        PrimaryButton(
          icon: Icons.check,
          label: 'Finish',
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
    final tones = AppTones.of(context);
    final (bg, fg, icon) = switch (state) {
      _OptState.correct => (
          tones.tint(AppTint.mint),
          tones.onTint(AppTint.mint),
          Icons.check_circle,
        ),
      _OptState.wrong => (
          Theme.of(context).colorScheme.errorContainer,
          Theme.of(context).colorScheme.onErrorContainer,
          Icons.cancel,
        ),
      _OptState.idle => (tones.cardMuted, tones.ink, null),
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

/// Target text where every word answers a long-press with a connection-first
/// explanation from the Teacher Brain (Phase 21). Teach first, dictionary
/// second — never a bare definition.
class _TappableTargetText extends ConsumerWidget {
  const _TappableTargetText({required this.text, this.onWordTap});

  final String text;

  /// Instrumentation hook (Phase 35/38): counts real word look-ups.
  final VoidCallback? onWordTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = TextStyle(
      color: AppTones.of(context).ink,
      fontSize: 25,
      height: 1.6,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    );
    final words = text.split(' ');
    return Wrap(
      children: [
        for (final w in words)
          GestureDetector(
            onLongPress: () {
              onWordTap?.call();
              _showWordExplanation(context, ref, w);
            },
            child: Text('$w ', style: style),
          ),
      ],
    );
  }
}

void _showWordExplanation(BuildContext context, WidgetRef ref, String raw) {
  final word = raw.replaceAll(RegExp(r'''[.,;:!?¡¿«»"'()…]'''), '');
  if (word.isEmpty) return;
  final brain = ref.read(teacherBrainProvider).value;
  final curriculum = ref.read(curriculumProvider).value;
  if (brain == null || curriculum == null) return;
  final e = explainWord(word, brain, curriculum);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTones.of(context).canvasTop,
    builder: (ctx) {
      final tones = AppTones.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
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
              Text(
                word,
                style: TextStyle(
                  color: tones.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              if (e.teachLine != null) ...[
                Text(
                  e.teachLine!,
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              if (e.mentalModelInsight != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb,
                      size: 18,
                      color: tones.solid(AppTint.sun),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        e.mentalModelInsight!,
                        style: TextStyle(
                          color: tones.inkSoft,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              if (e.relatedNames.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpace.sm - 2,
                  runSpacing: AppSpace.sm - 2,
                  children: [
                    for (final r in e.relatedNames) SoftChip(label: r),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              if (e.translation != null)
                Text(
                  'Dictionary: ${e.translation}',
                  style: TextStyle(color: tones.inkSoft, fontSize: 13.5),
                ),
              if (e.isEmpty)
                Text(
                  "We haven't met this word in a lesson yet — it will join "
                  'your map as you learn.',
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
