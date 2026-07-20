import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/pipeline.dart';
import '../../language/tutor.dart';
import '../language_providers.dart';
import '../ui.dart';

/// AI Tutor (ADR-0018): the Teacher Brain picks today's lesson, then a live
/// voice-first session. The session opens with real learner context
/// (misconceptions, weak concepts, skill mastery) — this tutor teaches THIS
/// learner, not a generic one.
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
      // Phase 2 simplification: the conversation screen carries only the
      // conversation. Back (in session) ends the lesson and records it;
      // everything configurable lives behind the one settings button.
      appBar: AppBar(
        leading: session == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: AppSpace.md),
                child: CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: 42,
                  tooltip: 'End session',
                  onTap: () =>
                      ref.read(tutorSessionProvider.notifier).reset(),
                ),
              ),
        title: const Text('AI Tutor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.md),
            child: CircleIconButton(
              icon: Icons.grid_view_rounded,
              size: 42,
              tooltip: 'Tutor settings',
              onTap: () => context.push('/tutor-settings'),
            ),
          ),
        ],
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: session == null
                ? const _ModeSelector()
                : _Session(
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

/// Memoised [splitTeacherReply]. A streaming reply rebuilds the transcript
/// many times a second, and every rebuild used to re-split every message in
/// the conversation; the split is pure, so the result is cached by input.
/// Bounded so a long session cannot grow it without limit.
final _splitCache = <String, TeacherReplyParts>{};
const _splitCacheMax = 64;

TeacherReplyParts _splitCached(String text, String target, String native) {
  final key = '$target|$native|$text';
  final hit = _splitCache[key];
  if (hit != null) return hit;
  final parts = splitTeacherReply(text, target, native);
  if (_splitCache.length >= _splitCacheMax) {
    _splitCache.remove(_splitCache.keys.first);
  }
  _splitCache[key] = parts;
  return parts;
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

/// A chat message. Tutor turns get the teacher avatar and a speak affordance;
/// learner turns are an accent-filled bubble on the right.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.isTutor,
    required this.text,
    this.onSpeak,
    this.streaming = false,
  });

  final bool isTutor;
  final String text;

  /// Tutor bubbles get a tap-to-hear speaker when speech is available.
  final VoidCallback? onSpeak;

  /// The live bubble mid-generation — draws a soft caret after the text.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final teacher = tones.solid(AppTint.mint);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isTutor ? tones.card : tones.accent,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isTutor ? 6 : 20),
          bottomRight: Radius.circular(isTutor ? 20 : 6),
        ),
        boxShadow: tones.softShadow,
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: isTutor ? tones.ink : tones.onAccent,
            fontSize: 15.5,
            height: 1.42,
          ),
          children: [
            ..._markdownSpans(text),
            if (streaming) const WidgetSpan(child: _StreamingCaret()),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm - 2),
      child: Row(
        mainAxisAlignment:
            isTutor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isTutor) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: teacher, shape: BoxShape.circle),
              child: Icon(
                Icons.school,
                size: 16,
                color: tones.onTint(AppTint.mint),
              ),
            ),
            const SizedBox(width: AppSpace.sm + 2),
          ],
          Flexible(child: bubble),
          if (isTutor && onSpeak != null)
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, size: 19),
              color: tones.inkSoft,
              visualDensity: VisualDensity.compact,
              tooltip: 'Hear this',
              onPressed: onSpeak,
            ),
        ],
      ),
    );
  }
}

/// Soft blinking caret appended to the streaming reply, so a partial answer
/// reads as "still arriving" rather than finished-but-truncated.
class _StreamingCaret extends StatefulWidget {
  const _StreamingCaret();

  @override
  State<_StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<_StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return FadeTransition(
      opacity: _c.drive(Tween(begin: 0.25, end: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 3, bottom: 1),
        child: Container(
          width: 8,
          height: 15,
          decoration: BoxDecoration(
            color: tones.solid(AppTint.mint),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 42, top: AppSpace.sm, bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tones.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final phase = (_c.value * 3 - i).clamp(0.0, 1.0);
                  final lift = phase < 0.5 ? phase : 1 - phase;
                  return Container(
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 5, bottom: lift * 5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: tones
                          .solid(AppTint.mint)
                          .withValues(alpha: 0.35 + lift * 0.65),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
          ],
        ),
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
    final tones = AppTones.of(context);
    final learner = ref.watch(languageLearnerProvider);
    final curriculum = ref.watch(curriculumProvider).value;
    final topMisconception = learner.misconceptions.all.firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.xl,
      ),
      children: [
        FadeInUp(
          child: GradientHero(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tones.solid(AppTint.mint),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school,
                    color: tones.onTint(AppTint.mint),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Your personal teacher',
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Every session starts from your real progress: '
                  '${learner.misconceptions.all.length} tracked misconceptions, '
                  'your weak concepts and skill mastery.',
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                if (topMisconception != null && curriculum != null) ...[
                  const SizedBox(height: AppSpace.lg),
                  SoftChip(
                    icon: Icons.build_circle,
                    tint: AppTint.lilac,
                    label: 'First up: '
                        '${curriculum.graph[topMisconception.conceptId]?.name ?? topMisconception.conceptId}',
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
    final tones = AppTones.of(context);
    final choice = ref.watch(teachingChoiceProvider);
    final info = choice == null
        ? null
        : _modes.firstWhere((m) => m.mode == choice.mode);
    return SoftCard(
      padding: const EdgeInsets.all(AppSpace.xl - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tones.tint(AppTint.mint),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  info?.icon ?? Icons.school,
                  size: 21,
                  color: tones.solid(AppTint.mint),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's lesson",
                      style: TextStyle(
                        color: tones.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Chosen from your progress',
                      style: TextStyle(color: tones.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            choice?.rationale ??
                'Getting your lesson ready from what you already know…',
            style: TextStyle(color: tones.ink, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: "Start today's lesson",
            icon: Icons.arrow_forward,
            onPressed: choice == null
                ? null
                : () => ref.read(tutorSessionProvider.notifier).start(
                      choice.mode,
                      focusConceptId: choice.focusConceptId,
                    ),
          ),
        ],
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
  _ConvState _conv = _ConvState.idle;
  int _spokenCount = 0;

  /// Typing is opt-in: the mockup's bottom bar is voice-first, and the
  /// composer slides in when the learner chooses to type.
  bool _typing = false;
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  int _lastLen = 0;
  String _lastTail = '';

  @override
  void dispose() {
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  /// Keeps the newest message in view as turns arrive and as a reply streams
  /// in — previously the transcript never followed the conversation.
  void _autoScroll() {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if ((_scroll.offset - target).abs() < 4) return;
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

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
    setState(() => _conv = _ConvState.processing);
    // A voice conversation speaks the reply back (app-level setting, so the
    // choice survives the session and lives in Tutor settings).
    ref.read(tutorVoiceRepliesProvider.notifier).state = true;
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

  static ({String label, AppTint tint})? _statusFor(_ConvState s) {
    return switch (s) {
      _ConvState.listening => (label: 'Listening…', tint: AppTint.sun),
      _ConvState.processing => (label: 'Thinking…', tint: AppTint.lilac),
      _ConvState.speaking => (
          label: 'Speaking  ·  tap the mic to interrupt',
          tint: AppTint.mint,
        ),
      _ConvState.error => (
          label: "Didn't catch that — hold the mic and try again",
          tint: AppTint.sun,
        ),
      _ConvState.idle => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final tones = AppTones.of(context);
    final speech = ref.watch(speechServiceProvider);
    final target = ref.watch(selectedLanguageProvider);
    final native = target == 'es' ? 'en' : 'es';
    final mentor =
        ref.watch(teacherSupportModeProvider) == TeacherSupportMode.mentor;
    final translate = ref.watch(tutorTranslateProvider);
    final voiceOn = ref.watch(tutorVoiceRepliesProvider);
    final lastTutorIdx = session.transcript.lastIndexWhere((t) => t.$1);

    // Auto-speak each new tutor turn while voice replies are on.
    final tutorTurns = session.transcript.where((t) => t.$1).length;
    if (voiceOn && tutorTurns > _spokenCount && !session.busy) {
      _spokenCount = tutorTurns;
      final last = session.transcript.lastWhere((t) => t.$1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _speak(last.$2));
    } else if (!voiceOn) {
      _spokenCount = tutorTurns; // toggling on later must not replay history
    }

    // Follow the conversation: a new turn, or more streamed text on the last
    // one, scrolls the newest content into view.
    final tail = session.transcript.isEmpty ? '' : session.transcript.last.$2;
    if (session.transcript.length != _lastLen || tail.length != _lastTail.length) {
      _lastLen = session.transcript.length;
      _lastTail = tail;
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoScroll());
    }

    return Column(
      children: [
        // Phase 2: no chip wall. The conversation IS the screen; teaching
        // state and toggles live in Tutor settings (top-right).
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.sm,
            ),
            children: [
              for (final (index, (isTutor, text))
                  in session.transcript.indexed)
                Builder(builder: (context) {
                  final isLastTutor = isTutor && index == lastTutorIdx;
                  final parts =
                      isTutor ? _splitCached(text, target, native) : null;
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
                  final supportText = (isTutor &&
                          mentor &&
                          !revealTranslation &&
                          parts != null &&
                          parts.target.isNotEmpty)
                      ? parts.support
                      : '';
                  return FadeInUp(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Bubble(
                          isTutor: isTutor,
                          text: bubbleText,
                          streaming:
                              isLastTutor && session.busy && text.isNotEmpty,
                          onSpeak: isTutor && speech.available
                              ? () => _speak(text)
                              : null,
                        ),
                        if (supportText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 42,
                              right: 40,
                              bottom: AppSpace.sm,
                            ),
                            child: Text(
                              supportText,
                              style: TextStyle(
                                color: tones.inkSoft,
                                fontSize: 13,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (revealTranslation)
                          _TranslationReveal(
                            // Tier 1: the native half the teacher already
                            // wrote. Tier 2/3 (neural translation, vocabulary
                            // gloss) are produced on demand by
                            // translateLatest and arrive via session state.
                            native: (parts?.support.trim().isNotEmpty ?? false)
                                ? parts!.support
                                : (session.latestTranslation ?? ''),
                            translating: session.translating,
                            nativeName: native == 'en' ? 'English' : 'Spanish',
                          ),
                      ],
                    ),
                  );
                }),
              // Only show the thinking dots before the first streamed token;
              // once text is arriving the caret carries the "still going" cue.
              if (session.busy &&
                  (lastTutorIdx < 0 ||
                      session.transcript[lastTutorIdx].$2.isEmpty))
                const _TypingIndicator(),
            ],
          ),
        ),
        _Composer(
          state: _conv,
          status: _statusFor(_conv),
          typing: _typing,
          busy: session.busy,
          micAvailable: speech.available,
          input: widget.input,
          inputFocus: _inputFocus,
          translateOn: translate,
          onHoldStart: _holdStart,
          onHoldEnd: _holdEnd,
          onTapMic: _tapMic,
          onSend: widget.onSend,
          onToggleTyping: () {
            setState(() => _typing = !_typing);
            if (_typing) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _inputFocus.requestFocus(),
              );
            } else {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          onToggleTranslate: () {
            final on = ref.read(tutorTranslateProvider.notifier).state =
                !ref.read(tutorTranslateProvider);
            // Turning the reveal on produces a translation when the reply has
            // no native half (neural model, else vocabulary gloss).
            if (on) {
              ref.read(tutorSessionProvider.notifier).translateLatest();
            }
          },
        ),
      ],
    );
  }
}

/// The voice-first bottom bar from the design: a large haloed mic in the
/// centre, flanked by the keyboard and translate actions, with the live
/// conversation status above it. Tapping the keyboard reveals the composer,
/// so typing remains a first-class path.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.state,
    required this.status,
    required this.typing,
    required this.busy,
    required this.micAvailable,
    required this.input,
    required this.inputFocus,
    required this.translateOn,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onTapMic,
    required this.onSend,
    required this.onToggleTyping,
    required this.onToggleTranslate,
  });

  final _ConvState state;
  final ({String label, AppTint tint})? status;
  final bool typing;
  final bool busy;
  final bool micAvailable;
  final TextEditingController input;
  final FocusNode inputFocus;
  final bool translateOn;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onTapMic;
  final void Function(String) onSend;
  final VoidCallback onToggleTyping;
  final VoidCallback onToggleTranslate;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final (micIcon, micTint) = switch (state) {
      _ConvState.listening => (Icons.graphic_eq_rounded, AppTint.sun),
      _ConvState.processing => (Icons.more_horiz_rounded, AppTint.lilac),
      _ConvState.speaking => (Icons.volume_up_rounded, AppTint.mint),
      _ConvState.error => (Icons.mic_off_rounded, AppTint.sun),
      _ConvState.idle => (Icons.mic_rounded, AppTint.mint),
    };
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live conversation status — grows/fades with the state change.
            AnimatedSize(
              duration: AppMotion.quick,
              curve: AppMotion.curve,
              child: status == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg,
                          vertical: AppSpace.sm - 1,
                        ),
                        decoration: BoxDecoration(
                          color: tones
                              .solid(status!.tint)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          status!.label,
                          style: TextStyle(
                            color: tones.solid(status!.tint),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
            ),
            // The composer slides in above the controls when typing.
            AnimatedSize(
              duration: AppMotion.quick,
              curve: AppMotion.curve,
              child: typing
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              focusNode: inputFocus,
                              enabled: !busy,
                              textInputAction: TextInputAction.send,
                              // No floating selection toolbar over the chat.
                              contextMenuBuilder: (_, _) =>
                                  const SizedBox.shrink(),
                              decoration: const InputDecoration(
                                hintText: 'Type a message…',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppSpace.lg + 2,
                                  vertical: AppSpace.md + 2,
                                ),
                              ),
                              onSubmitted: onSend,
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          CircleIconButton(
                            icon: Icons.arrow_upward_rounded,
                            filled: true,
                            size: 48,
                            tooltip: 'Send',
                            onTap: busy ? null : () => onSend(input.text),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleIconButton(
                  icon: typing
                      ? Icons.keyboard_hide_rounded
                      : Icons.keyboard_alt_outlined,
                  size: 52,
                  tooltip: typing ? 'Hide keyboard' : 'Type instead',
                  onTap: onToggleTyping,
                ),
                if (micAvailable)
                  HaloMicButton(
                    icon: micIcon,
                    color: tones.solid(micTint),
                    active: state != _ConvState.idle,
                    tooltip: 'Hold to talk',
                    onTap: onTapMic,
                    onLongPressStart: onHoldStart,
                    onLongPressEnd: onHoldEnd,
                  )
                else
                  CircleIconButton(
                    icon: Icons.arrow_upward_rounded,
                    filled: true,
                    size: 64,
                    tooltip: 'Send',
                    onTap: busy ? null : () => onSend(input.text),
                  ),
                // Translate: toggles the native-language reveal of the tutor's
                // most-recent reply. No new AI call.
                CircleIconButton(
                  icon: translateOn ? Icons.translate : Icons.language_rounded,
                  size: 52,
                  filled: translateOn,
                  tooltip: translateOn ? 'Hide translation' : 'Translate',
                  onTap: onToggleTranslate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The native-language reveal shown beneath the tutor's most-recent reply when
/// Translate is on. Collapsible via the Translate button; no new AI response —
/// it displays the native half the teacher already produced. When the reply is
/// target-language-only (no native half exists to show offline), it says so
/// honestly rather than inventing a translation.
class _TranslationReveal extends StatelessWidget {
  const _TranslationReveal({
    required this.native,
    required this.nativeName,
    this.translating = false,
  });

  final String native;
  final String nativeName;

  /// An on-demand translation is being produced (neural model path).
  final bool translating;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final has = native.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(
        left: 42,
        right: 40,
        top: AppSpace.xs,
        bottom: AppSpace.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: tones.tint(AppTint.mint).withValues(alpha: tones.dark ? 1 : 0.7),
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.translate, size: 16, color: tones.solid(AppTint.mint)),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                has
                    ? native
                    : translating
                        ? 'Translating…'
                        : 'No $nativeName translation is available for this '
                            'reply offline.',
                style: TextStyle(
                  color: tones.ink,
                  fontSize: 13.5,
                  height: 1.4,
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
