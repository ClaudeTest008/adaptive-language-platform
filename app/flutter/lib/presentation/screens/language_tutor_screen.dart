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

class _Session extends StatelessWidget {
  const _Session({
    required this.session,
    required this.input,
    required this.onSend,
  });

  final TutorSessionState session;
  final TextEditingController input;
  final void Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = _modes.firstWhere((m) => m.mode == session.mode);
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
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (isTutor, text) in session.transcript)
                Align(
                  alignment:
                      isTutor ? Alignment.centerLeft : Alignment.centerRight,
                  child: Card(
                    color: isTutor
                        ? scheme.secondaryContainer
                        : scheme.primaryContainer,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isTutor
                              ? scheme.onSecondaryContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              if (session.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    enabled: !session.busy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Reply to your tutor…',
                    ),
                    onSubmitted: onSend,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed:
                      session.busy ? null : () => onSend(input.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
