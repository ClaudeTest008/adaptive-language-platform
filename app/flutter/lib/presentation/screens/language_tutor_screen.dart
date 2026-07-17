import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/tutor.dart';
import '../language_providers.dart';

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
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          if (session != null)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'New session',
              onPressed: () => ref.read(tutorSessionProvider.notifier).reset(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: session == null ? const _ModeSelector() : _Session(
            session: session,
            input: _input,
            onSend: (text) {
              _input.clear();
              ref.read(tutorSessionProvider.notifier).send(text);
            },
          ),
        ),
      ),
    );
  }
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
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTutor ? scheme.secondaryContainer : scheme.primary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isTutor ? 4 : 18),
          bottomRight: Radius.circular(isTutor ? 18 : 4),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isTutor ? scheme.onSecondaryContainer : scheme.onPrimary,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your personal teacher',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every session starts from your real progress: '
                  '${learner.misconceptions.all.length} tracked misconceptions, '
                  'your weak concepts and skill mastery.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                if (topMisconception != null && curriculum != null) ...[
                  const SizedBox(height: 10),
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
        const SizedBox(height: 16),
        Text('Choose a mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 560 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            for (final m in _modes)
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () =>
                      ref.read(tutorSessionProvider.notifier).start(m.mode),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(m.icon, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          m.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Session view with voice (ADR-0020): speak-aloud tutor replies, a
/// "Voice replies" toggle that auto-speaks each new tutor turn, and a
/// microphone that dictates the learner's reply.
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
  bool _listening = false;
  int _spokenCount = 0;

  void _speak(String text) {
    ref.read(speechServiceProvider).speak(
      text,
      langCode: ref.read(languageBcp47Provider),
    );
  }

  Future<void> _dictate() async {
    if (_listening) return;
    setState(() => _listening = true);
    final heard = await ref
        .read(speechServiceProvider)
        .listen(langCode: ref.read(languageBcp47Provider));
    if (!mounted) return;
    setState(() => _listening = false);
    if (heard != null && heard.isNotEmpty) widget.input.text = heard;
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
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (isTutor, text) in session.transcript)
                _Bubble(
                  isTutor: isTutor,
                  text: text,
                  onSpeak: isTutor && speech.available
                      ? () => _speak(text)
                      : null,
                ),
              if (session.busy) const _TypingIndicator(),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                if (speech.available) ...[
                  IconButton.filledTonal(
                    icon: Icon(_listening ? Icons.hearing : Icons.mic),
                    tooltip: 'Speak your reply',
                    onPressed: session.busy || _listening ? null : _dictate,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.input,
                    enabled: !session.busy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Reply to your tutor…',
                    ),
                    onSubmitted: widget.onSend,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed:
                      session.busy ? null : () => widget.onSend(widget.input.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
