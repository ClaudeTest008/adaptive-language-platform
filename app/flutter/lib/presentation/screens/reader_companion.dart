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
    final tones = AppTones.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        const SizedBox(height: AppSpace.lg),
        FadeInUp(
          child: SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl,
              vertical: AppSpace.xxl,
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: tones.tint(AppTint.mint),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 34,
                    color: tones.onTint(AppTint.mint),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Chapter complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '“${story.title}” — keep the momentum going.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
        const SizedBox(height: AppSpace.xl),
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
    final tones = AppTones.of(context);
    final fg = primary ? tones.onAccent : tones.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: primary ? tones.accent : tones.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.lg,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: primary ? fg : tones.inkSoft,
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

  /// The question behind the current answer — shown as the learner bubble so
  /// the sheet reads as a conversation, like the tutor screen.
  String? _asked;
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
      _asked = question.trim();
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
    final tones = AppTones.of(context);
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
                Icon(Icons.forum_rounded, color: tones.solid(AppTint.mint)),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Reading companion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tones.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final q in const [
                  'Explain this page',
                  'Key grammar here',
                  'Give me an example',
                ])
                  SoftChip(label: q, onTap: () => _ask(q)),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            // The exchange scrolls inside its own box: a long answer must
            // never push the input off the sheet.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_asked != null)
                      _Bubble(text: _asked!, fromLearner: true),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(AppSpace.md),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_answer != null)
                      _Bubble(text: _answer!, fromLearner: false),
                  ],
                ),
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
                CircleIconButton(
                  icon: Icons.send_rounded,
                  filled: true,
                  size: 46,
                  onTap: _busy ? null : () => _ask(_input.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat bubble in the tutor screen's shape: companion on the left in the
/// card tone, learner on the right in the accent, tail corner tightened.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromLearner});

  final String text;
  final bool fromLearner;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm - 2),
      child: Row(
        mainAxisAlignment:
            fromLearner ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: fromLearner ? tones.accent : tones.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(fromLearner ? 20 : 6),
                  bottomRight: Radius.circular(fromLearner ? 6 : 20),
                ),
                boxShadow: tones.softShadow,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: fromLearner ? tones.onAccent : tones.ink,
                  fontSize: 15.5,
                  height: 1.42,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
