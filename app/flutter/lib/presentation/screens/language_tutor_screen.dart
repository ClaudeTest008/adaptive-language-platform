import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/pipeline.dart';
import '../../language/tutor.dart';
import '../language_providers.dart';
import '../ui.dart';

/// AI Tutor home (ADR-0018): mode selector → live session. The session
/// opens with real learner context (misconceptions, weak concepts,
/// skill mastery) — the tutor teaches THIS learner, not a generic one.
class LanguageTutorScreen extends ConsumerStatefulWidget {
  const LanguageTutorScreen({super.key});

  @override
  ConsumerState<LanguageTutorScreen> createState() =>
      _LanguageTutorScreenState();
}

class _LanguageTutorScreenState extends ConsumerState<LanguageTutorScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(tutorSessionProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('AI Tutor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Voice settings',
            onPressed: () => context.push('/voice-settings'),
          ),
          if (session != null)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'New session',
              onPressed: () => ref.read(tutorSessionProvider.notifier).reset(),
            ),
        ],
      ),
      body: AtmosphericBackground(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: session == null ? const _ModeSelector() : _Session(
            session: session,
            input: _input,
            onSend: (text) {
              if (text.trim().isEmpty) return;
              _input.clear();
              // Dismiss the keyboard so the reply lands cleanly.
              FocusManager.instance.primaryFocus?.unfocus();
              ref.read(tutorSessionProvider.notifier).send(text);
            },
          ),
        ),
      ),
      ),
    );
  }
}

/// Renders `**bold**` and `*italic*` emphasis as styled spans so the chat
/// never shows literal asterisks (the tutor prompts emphasise concepts and
/// example forms in markdown).
List<InlineSpan> _markdownSpans(String text) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);
  var i = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
    final bold = m[1] != null;
    spans.add(TextSpan(
      text: bold ? m[1] : m[2],
      style: bold
          ? const TextStyle(fontWeight: FontWeight.w700)
          : const TextStyle(fontStyle: FontStyle.italic),
    ));
    i = m.end;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
  return spans;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isTutor, required this.text, this.onSpeak});

  final bool isTutor;
  final String text;

  /// Tutor bubbles get a tap-to-hear speaker when speech is available.
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isTutor ? scheme.secondaryContainer : scheme.primary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isTutor ? 4 : 18),
          bottomRight: Radius.circular(isTutor ? 18 : 4),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: isTutor ? scheme.onSecondaryContainer : scheme.onPrimary,
            height: 1.35,
          ),
          children: _markdownSpans(text),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        mainAxisAlignment:
            isTutor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isTutor) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.school,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (isTutor && onSpeak != null)
            IconButton(
              icon: const Icon(Icons.volume_up, size: 18),
              tooltip: 'Hear this',
              onPressed: onSpeak,
            ),
        ],
      ),
    );
  }
}

/// Three softly pulsing dots — the tutor is "thinking".
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 8, bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final phase = (_c.value * 3 - i).clamp(0.0, 1.0);
                final lift = phase < 0.5 ? phase : 1 - phase;
                return Container(
                  margin: EdgeInsets.only(
                    right: 4,
                    bottom: 2 + lift * 6,
                  ),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.4 + lift * 0.6),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ModeInfo {
  const _ModeInfo(this.mode, this.title, this.subtitle, this.icon);

  final TutorMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
}

const _modes = [
  _ModeInfo(
    TutorMode.teacher,
    'Teacher',
    'Explains concepts, repairs misconceptions',
    Icons.school,
  ),
  _ModeInfo(
    TutorMode.conversation,
    'Conversation',
    'Natural dialogue at your level',
    Icons.forum,
  ),
  _ModeInfo(
    TutorMode.coach,
    'Coach',
    'Daily goals, motivation, planning',
    Icons.sports,
  ),
  _ModeInfo(
    TutorMode.socratic,
    'Socratic',
    'Discover answers through questions',
    Icons.psychology_alt,
  ),
  _ModeInfo(
    TutorMode.grammar,
    'Grammar',
    'Patterns, contrasted with English',
    Icons.account_tree,
  ),
  _ModeInfo(
    TutorMode.immersion,
    'Immersion',
    'Target language only',
    Icons.language,
  ),
];

class _ModeSelector extends ConsumerWidget {
  const _ModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final learner = ref.watch(languageLearnerProvider);
    final curriculum = ref.watch(curriculumProvider).value;
    final topMisconception = learner.misconceptions.all.firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        FadeInUp(
          child: GradientHero(
            colors: [scheme.primaryContainer, scheme.tertiaryContainer],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your personal teacher',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Every session starts from your real progress: '
                  '${learner.misconceptions.all.length} tracked misconceptions, '
                  'your weak concepts and skill mastery.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                if (topMisconception != null && curriculum != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Chip(
                    avatar: Icon(Icons.build_circle, size: 16,
                        color: scheme.onErrorContainer),
                    backgroundColor: scheme.errorContainer,
                    label: Text(
                      'First up: '
                      '${curriculum.graph[topMisconception.conceptId]?.name ?? topMisconception.conceptId}',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        const FadeInUp(delayMs: 60, child: _TodaysLessonCard()),
      ],
    );
  }
}

/// The unified teacher (Phase 18): no mode selector. The Teacher Brain chooses
/// today's strategy and focus; the learner just starts. The six internal
/// strategies still exist — the teacher picks among them automatically.
class _TodaysLessonCard extends ConsumerWidget {
  const _TodaysLessonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final choice = ref.watch(teachingChoiceProvider);
    final info = choice == null
        ? null
        : _modes.firstWhere((m) => m.mode == choice.mode);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    info?.icon ?? Icons.school,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's lesson", style: text.titleMedium),
                      Text(
                        'Your teacher chose this from your progress',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              choice?.rationale ??
                  'Getting your lesson ready from what you already know…',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: choice == null
                    ? null
                    : () => ref
                          .read(tutorSessionProvider.notifier)
                          .start(
                            choice.mode,
                            focusConceptId: choice.focusConceptId,
                          ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Start today's lesson"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice-conversation state machine (Phase 13). Idle → Listening (mic held)
/// → Processing (released, tutor thinking) → Speaking (reply spoken).
/// Pressing the mic while Speaking barges in and returns to Listening.
enum _ConvState { idle, listening, processing, speaking, error }

/// Session view with voice (ADR-0020): speak-aloud tutor replies, a
/// "Voice replies" toggle that auto-speaks each new tutor turn, and a
/// press-and-hold microphone that runs a real voice conversation.
class _Session extends ConsumerStatefulWidget {
  const _Session({
    required this.session,
    required this.input,
    required this.onSend,
  });

  final TutorSessionState session;
  final TextEditingController input;
  final void Function(String) onSend;

  @override
  ConsumerState<_Session> createState() => _SessionState();
}

class _SessionState extends ConsumerState<_Session> {
  bool _voiceOn = false;
  _ConvState _conv = _ConvState.idle;
  int _spokenCount = 0;

  Future<void> _speak(String text) async {
    // Strict language pipeline (Phase 21): only target-language sentences may
    // reach the target-language voice. English support text is never
    // synthesized with the Spanish voice.
    final target = ref.read(selectedLanguageProvider);
    final native = target == 'es' ? 'en' : 'es';
    final safe = speechSafeText(text, target, native);
    if (safe.isEmpty) return;
    final speech = ref.read(speechServiceProvider);
    if (mounted) setState(() => _conv = _ConvState.speaking);
    await speech.speak(
      safe,
      langCode: ref.read(languageBcp47Provider),
      speed: ref.read(speechSpeedProvider),
    );
    // Only fall back to idle if nothing else changed the state meanwhile
    // (e.g. the learner already barged in with the mic).
    if (mounted && _conv == _ConvState.speaking) {
      setState(() => _conv = _ConvState.idle);
    }
  }

  /// Press-and-hold conversation. Hold → Listening; release → Processing →
  /// the tutor replies and speaks (Speaking). Pressing the mic at any time
  /// barges in: any AI speech is cut off instantly and we go back to
  /// Listening — the ChatGPT-Voice feel.
  Future<void> _holdStart() async {
    final speech = ref.read(speechServiceProvider);
    await speech.stop(); // barge-in
    if (!mounted) return;
    setState(() => _conv = _ConvState.listening);
    final heard =
        await speech.listen(langCode: ref.read(languageBcp47Provider));
    if (!mounted) return;
    if (heard == null || heard.trim().isEmpty) {
      setState(() => _conv = _ConvState.error);
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (mounted && _conv == _ConvState.error) {
        setState(() => _conv = _ConvState.idle);
      }
      return;
    }
    setState(() {
      _conv = _ConvState.processing;
      _voiceOn = true; // speak the reply back during a voice conversation
    });
    widget.onSend(heard);
  }

  /// Release finalizes the utterance so listen() resolves at once.
  void _holdEnd() {
    if (_conv == _ConvState.listening) {
      ref.read(speechServiceProvider).stop();
    }
  }

  /// A quick tap while the tutor is speaking = immediate barge-in stop.
  void _tapMic() {
    if (_conv == _ConvState.speaking) {
      ref.read(speechServiceProvider).stop();
      setState(() => _conv = _ConvState.idle);
    }
  }

  static ({String label, Color Function(ColorScheme) color})? _statusFor(
    _ConvState s,
  ) {
    return switch (s) {
      _ConvState.listening => (
          label: 'Listening…',
          color: (c) => c.error,
        ),
      _ConvState.processing => (
          label: 'Processing…',
          color: (c) => c.tertiary,
        ),
      _ConvState.speaking => (
          label: 'Speaking…  ·  tap the mic to interrupt',
          color: (c) => c.primary,
        ),
      _ConvState.error => (
          label: "Didn't catch that — hold the mic and try again",
          color: (c) => c.error,
        ),
      _ConvState.idle => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final speech = ref.watch(speechServiceProvider);
    final mode = _modes.firstWhere((m) => m.mode == session.mode);

    // Auto-speak each new tutor turn while voice replies are on.
    final tutorTurns = session.transcript.where((t) => t.$1).length;
    if (_voiceOn && tutorTurns > _spokenCount && !session.busy) {
      _spokenCount = tutorTurns;
      final last = session.transcript.lastWhere((t) => t.$1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _speak(last.$2));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Chip(
                avatar: Icon(mode.icon, size: 16),
                label: Text('${mode.title} mode'),
              ),
              if (session.context.focusConcept != null)
                Chip(
                  avatar: const Icon(Icons.center_focus_strong, size: 16),
                  label: Text('Focus: ${session.context.focusConcept!.name}'),
                ),
              Chip(
                avatar: const Icon(Icons.psychology, size: 16),
                label: Text(
                  '${session.context.misconceptions.length} misconceptions in context',
                ),
              ),
              if (speech.available)
                FilterChip(
                  avatar: Icon(
                    _voiceOn ? Icons.volume_up : Icons.volume_off,
                    size: 16,
                  ),
                  label: const Text('Voice replies'),
                  selected: _voiceOn,
                  onSelected: (v) {
                    setState(() {
                      _voiceOn = v;
                      _spokenCount = tutorTurns; // don't replay history
                    });
                  },
                ),
              // Immersion vs Mentor (Phase 21): mentor shows English support
              // under Spanish replies; immersion hides it. Audio is Spanish
              // either way.
              Builder(builder: (context) {
                final support = ref.watch(teacherSupportModeProvider);
                final immersive = support == TeacherSupportMode.immersion;
                return FilterChip(
                  avatar: Icon(
                    immersive ? Icons.public : Icons.school_outlined,
                    size: 16,
                  ),
                  label: Text(immersive ? 'Immersion' : 'Mentor'),
                  selected: immersive,
                  onSelected: (v) =>
                      ref.read(teacherSupportModeProvider.notifier).state = v
                      ? TeacherSupportMode.immersion
                      : TeacherSupportMode.mentor,
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              for (final (index, (isTutor, text))
                  in session.transcript.indexed)
                Builder(builder: (context) {
                  final target = ref.watch(selectedLanguageProvider);
                  final native = target == 'es' ? 'en' : 'es';
                  final mentor = ref.watch(teacherSupportModeProvider) ==
                      TeacherSupportMode.mentor;
                  final translate = ref.watch(tutorTranslateProvider);
                  final lastTutorIdx =
                      session.transcript.lastIndexWhere((t) => t.$1);
                  final isLastTutor = isTutor && index == lastTutorIdx;
                  final parts = isTutor
                      ? splitTeacherReply(text, target, native)
                      : null;
                  // Immersion: show only the target-language body. Mentor:
                  // target body + support underneath. Learner bubbles as-is.
                  final bubbleText = parts == null
                      ? text
                      : parts.target.isEmpty
                      ? text // fully-native line (e.g. notebook greeting)
                      : parts.target;
                  // The Translate reveal owns the most-recent reply's native
                  // text — suppress the auto-support there to avoid duplicating.
                  final revealTranslation = isLastTutor && translate;
                  final supportText =
                      (isTutor && mentor && !revealTranslation &&
                          parts != null && parts.target.isNotEmpty)
                      ? parts.support
                      : '';
                  return FadeInUp(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Bubble(
                          isTutor: isTutor,
                          text: bubbleText,
                          onSpeak: isTutor && speech.available
                              ? () => _speak(text)
                              : null,
                        ),
                        if (supportText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 44,
                              right: 24,
                              bottom: 8,
                            ),
                            child: Text(
                              supportText,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        if (revealTranslation)
                          _TranslationReveal(
                            native: parts?.support ?? '',
                            nativeName: native == 'en' ? 'English' : 'Spanish',
                          ),
                      ],
                    ),
                  );
                }),
              if (session.busy) const _TypingIndicator(),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Conversation status pill — fades in on state change.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: AppMotion.curve,
                  child: Builder(
                    builder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      final status = _statusFor(_conv);
                      if (status == null) return const SizedBox.shrink();
                      final c = status.color(scheme);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                            vertical: AppSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            status.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: c),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    if (speech.available) ...[
                      _HoldMic(
                        state: _conv,
                        onHoldStart: _holdStart,
                        onHoldEnd: _holdEnd,
                        onTap: _tapMic,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: TextField(
                        controller: widget.input,
                        enabled: !session.busy,
                        textInputAction: TextInputAction.send,
                        // No floating selection toolbar over the chat.
                        contextMenuBuilder: (_, _) =>
                            const SizedBox.shrink(),
                        decoration: const InputDecoration(
                          hintText: 'Hold the mic to talk, or type…',
                        ),
                        onSubmitted: widget.onSend,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: session.busy
                          ? null
                          : () => widget.onSend(widget.input.text),
                    ),
                    const SizedBox(width: 8),
                    // Translate: toggles the native-language reveal of the
                    // tutor's most-recent reply. Circular, matching the mic and
                    // send buttons; no new AI call.
                    _TranslateButton(
                      active: ref.watch(tutorTranslateProvider),
                      onTap: () => ref
                          .read(tutorTranslateProvider.notifier)
                          .update((v) => !v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular Translate action, styled to match the mic/send buttons. Filled
/// when active (translation shown), tonal when off. Tooltip 'Translate'.
class _TranslateButton extends StatelessWidget {
  const _TranslateButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(active ? Icons.translate : Icons.translate_outlined);
    return active
        ? IconButton.filled(
            icon: icon,
            tooltip: 'Hide translation',
            onPressed: onTap,
          )
        : IconButton.filledTonal(
            icon: icon,
            tooltip: 'Translate',
            onPressed: onTap,
          );
  }
}

/// The native-language reveal shown beneath the tutor's most-recent reply when
/// Translate is on. Collapsible via the Translate button; no new AI response —
/// it displays the native half the teacher already produced. When the reply is
/// target-language-only (no native half exists to show offline), it says so
/// honestly rather than inventing a translation.
class _TranslationReveal extends StatelessWidget {
  const _TranslationReveal({required this.native, required this.nativeName});

  final String native;
  final String nativeName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final has = native.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 24, top: 2, bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.translate, size: 16, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                has
                    ? native
                    : 'No $nativeName translation for this reply — it was '
                        'spoken in the target language only.',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontStyle: has ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Press-and-hold conversation mic: colour + icon reflect the live
/// conversation state, and it pulses gently while listening.
class _HoldMic extends StatelessWidget {
  const _HoldMic({
    required this.state,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onTap,
  });

  final _ConvState state;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, icon) = switch (state) {
      _ConvState.listening => (scheme.error, Icons.graphic_eq_rounded),
      _ConvState.processing => (scheme.tertiary, Icons.more_horiz_rounded),
      _ConvState.speaking => (scheme.primary, Icons.volume_up_rounded),
      _ConvState.error => (scheme.error, Icons.mic_off_rounded),
      _ConvState.idle => (scheme.primary, Icons.mic_rounded),
    };
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: state == _ConvState.listening
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: scheme.onPrimary, size: 22),
      ),
    );
  }
}
