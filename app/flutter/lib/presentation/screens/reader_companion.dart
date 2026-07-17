import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/chat_model.dart';
import '../../language/story.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Shown after the last page instead of a forced quiz (Phase 15 reading
/// flow): the learner is free to keep reading; the quiz is one optional
/// choice on this card, never required.
class CompletionCard extends StatelessWidget {
  const CompletionCard({
    super.key,
    required this.story,
    required this.onContinue,
    required this.onCompanion,
    required this.onSpeaking,
    this.onVocab,
    this.onQuiz,
  });

  final Story story;
  final VoidCallback onContinue;
  final VoidCallback onCompanion;
  final VoidCallback onSpeaking;
  final VoidCallback? onVocab;
  final VoidCallback? onQuiz;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        const SizedBox(height: AppSpace.xl),
        FadeInUp(
          child: Center(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.check_rounded,
                  size: 36, color: scheme.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'Chapter complete',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          '“${story.title}” — keep the momentum going.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpace.xl),
        _Action(
          icon: Icons.menu_book_rounded,
          label: 'Continue reading',
          primary: true,
          onTap: onContinue,
        ),
        _Action(
          icon: Icons.forum_outlined,
          label: 'Reading companion',
          onTap: onCompanion,
        ),
        if (onVocab != null)
          _Action(
            icon: Icons.style_outlined,
            label: 'Vocabulary review',
            onTap: onVocab!,
          ),
        _Action(
          icon: Icons.record_voice_over_outlined,
          label: 'Speaking practice',
          onTap: onSpeaking,
        ),
        if (onQuiz != null)
          _Action(
            icon: Icons.quiz_outlined,
            label: 'Take the quiz (optional)',
            onTap: onQuiz!,
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: primary ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md + 2,
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: primary ? scheme.onPrimary : scheme.onSurface),
                const SizedBox(width: AppSpace.md),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: primary ? scheme.onPrimary : scheme.onSurface,
                        fontWeight: FontWeight.w600,
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

/// Ask-the-tutor-without-leaving-the-book sheet. Reuses the AiChatModel
/// seam (tutorModelProvider): the demo model answers offline; a vendor
/// model gives premium answers with no UI change.
class ReadingCompanionSheet extends ConsumerStatefulWidget {
  const ReadingCompanionSheet({
    super.key,
    required this.story,
    required this.paragraph,
  });

  final Story story;
  final String paragraph;

  @override
  ConsumerState<ReadingCompanionSheet> createState() =>
      _ReadingCompanionSheetState();
}

class _ReadingCompanionSheetState
    extends ConsumerState<ReadingCompanionSheet> {
  final _input = TextEditingController();
  String? _answer;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    if (question.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _answer = null;
    });
    final model = ref.read(tutorModelProvider);
    final reply = await model.complete([
      AiMessage(
        AiRole.system,
        'You are a warm, encouraging Spanish reading tutor. The learner is '
        'reading this passage: "${widget.paragraph}". Answer briefly, '
        'clearly and kindly.',
      ),
      AiMessage(AiRole.user, question),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _answer = reply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_rounded, color: scheme.primary),
                const SizedBox(width: AppSpace.sm),
                Text('Reading companion', style: text.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              children: [
                for (final q in const [
                  'Explain this page',
                  'Key grammar here',
                  'Give me an example',
                ])
                  ActionChip(label: Text(q), onPressed: () => _ask(q)),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(AppSpace.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_answer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  _answer!,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about this page…',
                    ),
                    onSubmitted: _ask,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _busy ? null : () => _ask(_input.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
