import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/exercises.dart';
import '../../language/misconceptions.dart';
import '../language_providers.dart';

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
    return Scaffold(
      appBar: AppBar(
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TypeChip(type: item.type),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    item.prompt,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._inputFor(item, session),
              if (session.answered) ...[
                const SizedBox(height: 16),
                _FeedbackBanner(session: session),
                for (final m in session.feedback)
                  _TeacherNote(misconception: m),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    session.index + 1 < session.items.length
                        ? Icons.arrow_forward
                        : Icons.flag,
                  ),
                  label: Text(
                    session.index + 1 < session.items.length
                        ? 'Next'
                        : 'Finish',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _inputFor(ExerciseItem item, LanguagePracticeState session) {
    final scheme = Theme.of(context).colorScheme;
    switch (item.type) {
      case ExerciseType.listening:
        return [
          Center(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.volume_up),
              label: const Text('Play again'),
              onPressed: () => ref.read(speechServiceProvider).speak(
                item.audio ?? item.answer,
                langCode: ref.read(languageBcp47Provider),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final option in item.options)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: !session.answered
                  ? null
                  : checkAnswer(item, option)
                  ? Colors.green.withValues(alpha: 0.15)
                  : option == session.given
                  ? scheme.errorContainer
                  : null,
              child: ListTile(
                title: Text(option),
                trailing: !session.answered
                    ? null
                    : checkAnswer(item, option)
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : option == session.given
                    ? Icon(Icons.cancel, color: scheme.error)
                    : null,
                onTap: session.answered ? null : () => _submit(option),
              ),
            ),
        ];

      case ExerciseType.multipleChoice:
      case ExerciseType.readingComprehension:
        return [
          for (final option in item.options)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: !session.answered
                  ? null
                  : checkAnswer(item, option)
                  ? Colors.green.withValues(alpha: 0.15)
                  : option == session.given
                  ? scheme.errorContainer
                  : null,
              child: ListTile(
                title: Text(option),
                trailing: !session.answered
                    ? null
                    : checkAnswer(item, option)
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : option == session.given
                    ? Icon(Icons.cancel, color: scheme.error)
                    : null,
                onTap: session.answered ? null : () => _submit(option),
              ),
            ),
        ];

      case ExerciseType.fillInBlank:
      case ExerciseType.translation:
        return [
          TextField(
            controller: _textController,
            enabled: !session.answered,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: item.type == ExerciseType.fillInBlank
                  ? 'Missing word'
                  : 'Your translation',
            ),
            onSubmitted: session.answered ? null : _submit,
          ),
          const SizedBox(height: 8),
          if (!session.answered)
            FilledButton.tonal(
              onPressed: () => _submit(_textController.text),
              child: const Text('Check'),
            ),
        ];

      case ExerciseType.sentenceBuilding:
        return [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_built.isEmpty)
                  Text(
                    'Tap the words below in order…',
                    style: TextStyle(color: scheme.onSurfaceVariant),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in _wordBankLeft(item))
                ActionChip(
                  label: Text(w),
                  onPressed: session.answered
                      ? null
                      : () => setState(() => _built.add(w)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!session.answered)
            FilledButton.tonal(
              onPressed:
                  _built.isEmpty ? null : () => _submit(_built.join(' ')),
              child: const Text('Check'),
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
      child: Chip(avatar: Icon(icon, size: 16), label: Text(label)),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.session});

  final LanguagePracticeState session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final correct = session.wasCorrect == true;
    return Card(
      color: correct
          ? Colors.green.withValues(alpha: 0.15)
          : scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          correct ? Icons.check_circle : Icons.cancel,
          color: correct ? Colors.green : scheme.onErrorContainer,
        ),
        title: Text(correct ? '¡Correcto!' : 'Not quite'),
        subtitle: correct
            ? null
            : Text("Answer: '${session.current.answer}'"),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher note',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    misconception.explanation,
                    style: TextStyle(color: scheme.onSecondaryContainer),
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
    final scheme = Theme.of(context).colorScheme;
    final score = session.correctCount / session.items.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Session complete')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          color: score >= 0.7 ? Colors.green : scheme.tertiary,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        '${(v * 100).round()}%',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${session.correctCount}/${session.items.length} correct',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Practice again'),
                  onPressed: () {
                    ref.read(languagePracticeProvider.notifier)
                      ..reset()
                      ..start();
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Back to Language Lab'),
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
    );
  }
}
