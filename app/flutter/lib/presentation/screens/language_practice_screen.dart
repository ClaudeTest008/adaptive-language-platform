import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/exercises.dart';
import '../../language/misconceptions.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Text-first exercise session (ADR-0017). Every submission is a real
/// answer event: core engine mastery, misconception detection and signal
/// updates all happen live — wrong answers surface teacher notes inline.
class LanguagePracticeScreen extends ConsumerStatefulWidget {
  const LanguagePracticeScreen({super.key, this.focus = const []});

  /// Concept ids to practice first (e.g. the repair block).
  final List<String> focus;

  @override
  ConsumerState<LanguagePracticeScreen> createState() =>
      _LanguagePracticeScreenState();
}

class _LanguagePracticeScreenState
    extends ConsumerState<LanguagePracticeScreen> {
  final _textController = TextEditingController();
  final _built = <String>[];

  /// Index whose listening audio has already auto-played (play once).
  int? _autoPlayed;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit(String given) {
    // Close the keyboard as soon as an answer is submitted so feedback and
    // the Next button aren't hidden behind it.
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(languagePracticeProvider.notifier).submit(given);
  }

  void _next() {
    // Dismiss the keyboard so it never lingers over the next item — it
    // reopens only when the learner taps a text field again.
    FocusManager.instance.primaryFocus?.unfocus();
    _textController.clear();
    _built.clear();
    ref.read(languagePracticeProvider.notifier).next();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(languagePracticeProvider);

    if (session == null) {
      // Start once the curriculum is available (handles cold deep links
      // where this screen builds before the asset future resolves).
      if (ref.watch(curriculumProvider).hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(languagePracticeProvider) == null) {
            ref
                .read(languagePracticeProvider.notifier)
                .start(focusConceptIds: widget.focus);
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.finished) return _Summary(session: session);

    final item = session.current;
    // Auto-play a listening item's audio once when it appears.
    if (item.type == ExerciseType.listening && _autoPlayed != session.index) {
      _autoPlayed = session.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(speechServiceProvider).speak(
          item.audio ?? item.answer,
          langCode: ref.read(languageBcp47Provider),
        );
      });
    }
    final tones = AppTones.of(context);
    final last = session.index + 1 >= session.items.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Practice ${session.index + 1}/${session.items.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: (session.index + (session.answered ? 1 : 0)) /
                  session.items.length,
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) =>
                LinearProgressIndicator(value: v, minHeight: 4),
          ),
        ),
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                _TypeChip(type: item.type),
                const SizedBox(height: AppSpace.md),
                FadeInUp(
                  key: ValueKey(session.index),
                  child: SoftCard(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Text(
                      item.prompt,
                      style: TextStyle(
                        color: tones.ink,
                        fontSize: 21,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                ..._inputFor(item, session),
                if (session.answered) ...[
                  const SizedBox(height: AppSpace.lg),
                  _FeedbackBanner(session: session),
                  for (final m in session.feedback)
                    _TeacherNote(misconception: m),
                  const SizedBox(height: AppSpace.lg),
                  PrimaryButton(
                    label: last ? 'Finish' : 'Next',
                    icon: last ? Icons.flag_rounded : Icons.arrow_forward,
                    onPressed: _next,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One answer option. Selected/correct/wrong states stay unmistakable:
  /// mint fill + check for the answer, error fill + cross for a wrong pick.
  Widget _option(ExerciseItem item, LanguagePracticeState session, String o) {
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isAnswer = session.answered && checkAnswer(item, o);
    final isWrongPick = session.answered && !isAnswer && o == session.given;
    final green = tones.solid(AppTint.mint);
    final fg = isAnswer
        ? green
        : isWrongPick
            ? scheme.error
            : tones.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: SoftCard(
        tint: isAnswer ? AppTint.mint : null,
        elevated: !session.answered,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md + 2,
        ),
        onTap: session.answered ? null : () => _submit(o),
        child: Row(
          children: [
            Expanded(
              child: Text(
                o,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 15.5,
                  fontWeight: isAnswer || isWrongPick
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            if (isAnswer || isWrongPick) ...[
              const SizedBox(width: AppSpace.sm),
              Icon(
                isAnswer ? Icons.check_circle : Icons.cancel,
                color: fg,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _inputFor(ExerciseItem item, LanguagePracticeState session) {
    final tones = AppTones.of(context);
    switch (item.type) {
      case ExerciseType.listening:
        return [
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.volume_up_rounded, size: 19),
              label: const Text('Play again'),
              onPressed: () => ref.read(speechServiceProvider).speak(
                item.audio ?? item.answer,
                langCode: ref.read(languageBcp47Provider),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          for (final option in item.options) _option(item, session, option),
        ];

      case ExerciseType.multipleChoice:
      case ExerciseType.readingComprehension:
        return [
          for (final option in item.options) _option(item, session, option),
        ];

      case ExerciseType.fillInBlank:
      case ExerciseType.translation:
        return [
          TextField(
            controller: _textController,
            enabled: !session.answered,
            textInputAction: TextInputAction.done,
            // No floating selection toolbar over the exercise.
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            decoration: InputDecoration(
              labelText: item.type == ExerciseType.fillInBlank
                  ? 'Missing word'
                  : 'Your translation',
            ),
            onSubmitted: session.answered ? null : _submit,
          ),
          const SizedBox(height: AppSpace.md),
          if (!session.answered)
            PrimaryButton(
              label: 'Check',
              onPressed: () => _submit(_textController.text),
            ),
        ];

      case ExerciseType.sentenceBuilding:
        return [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: tones.cardMuted.withValues(alpha: tones.dark ? 1 : 0.6),
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            child: Wrap(
              spacing: AppSpace.sm - 2,
              runSpacing: AppSpace.sm - 2,
              children: [
                if (_built.isEmpty)
                  Text(
                    'Tap the words below in order…',
                    style: TextStyle(color: tones.inkSoft),
                  ),
                for (final (i, w) in _built.indexed)
                  InputChip(
                    label: Text(w),
                    onDeleted: session.answered
                        ? null
                        : () => setState(() => _built.removeAt(i)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm - 2,
            runSpacing: AppSpace.sm - 2,
            children: [
              for (final w in _wordBankLeft(item))
                SoftChip(
                  label: w,
                  onTap: session.answered
                      ? null
                      : () => setState(() => _built.add(w)),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          if (!session.answered)
            PrimaryButton(
              label: 'Check',
              onPressed:
                  _built.isEmpty ? null : () => _submit(_built.join(' ')),
            ),
        ];

      // Remaining types arrive with their engines (Phases 5–6).
      // ignore: unreachable_switch_default
      default:
        return [const Text('Exercise type not available yet.')];
    }
  }

  /// Word bank minus already-used words (multiset semantics).
  List<String> _wordBankLeft(ExerciseItem item) {
    final left = [...item.options];
    for (final w in _built) {
      left.remove(w);
    }
    return left;
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final ExerciseType type;

  static const _labels = {
    ExerciseType.multipleChoice: ('Vocabulary', Icons.style),
    ExerciseType.fillInBlank: ('Fill in the blank', Icons.edit),
    ExerciseType.translation: ('Translation', Icons.translate),
    ExerciseType.sentenceBuilding: ('Sentence building', Icons.reorder),
    ExerciseType.readingComprehension: ('Reading', Icons.menu_book),
    ExerciseType.listening: ('Listening', Icons.headphones),
  };

  @override
  Widget build(BuildContext context) {
    final (label, icon) =
        _labels[type] ?? (type.name, Icons.fitness_center);
    return Align(
      alignment: Alignment.centerLeft,
      child: SoftChip(label: label, icon: icon, tint: AppTint.lilac),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.session});

  final LanguagePracticeState session;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final correct = session.wasCorrect == true;
    final tint = correct ? AppTint.mint : AppTint.sun;
    final accent = correct ? tones.solid(AppTint.mint) : scheme.error;
    return SoftCard(
      tint: tint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(correct ? Icons.check_circle : Icons.cancel, color: accent),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? '¡Correcto!' : 'Not quite',
                  style: TextStyle(
                    color: tones.onTint(tint),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (!correct) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    "Answer: '${session.current.answer}'",
                    style: TextStyle(
                      color: tones.onTint(tint).withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline teacher note — the misconception engine speaking.
class _TeacherNote extends StatelessWidget {
  const _TeacherNote({required this.misconception});

  final Misconception misconception;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final fg = tones.onTint(AppTint.lilac);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: SoftCard(
        tint: AppTint.lilac,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school, color: tones.solid(AppTint.lilac)),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher note',
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    misconception.explanation,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.88),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.session});

  final LanguagePracticeState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final score = session.correctCount / session.items.length;
    final accent =
        score >= 0.7 ? tones.solid(AppTint.mint) : tones.solid(AppTint.sun);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Session complete'),
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInUp(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: score),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 128,
                            height: 128,
                            child: CircularProgressIndicator(
                              value: v,
                              strokeWidth: 10,
                              strokeCap: StrokeCap.round,
                              color: accent,
                              backgroundColor: tones.cardMuted,
                            ),
                          ),
                          Text(
                            '${(v * 100).round()}%',
                            style: TextStyle(
                              color: tones.ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    '${session.correctCount}/${session.items.length} correct',
                    style: TextStyle(
                      color: tones.inkSoft,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  PrimaryButton(
                    label: 'Practice again',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      ref.read(languagePracticeProvider.notifier)
                        ..reset()
                        ..start();
                    },
                  ),
                  const SizedBox(height: AppSpace.md),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Back to Language Lab'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tones.ink,
                      side: BorderSide(color: tones.hairline),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () {
                      ref.read(languagePracticeProvider.notifier).reset();
                      context.go('/language');
                    },
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
