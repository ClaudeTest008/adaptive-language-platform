import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/pipeline.dart';
import '../language_providers.dart';
import '../ui.dart';

/// AI Tutor settings (Phase 2 simplification): everything that used to sit
/// as chips on top of the conversation lives here instead. The conversation
/// screen shows the conversation; configuration and teaching state are one
/// tap away, not in the learner's face on every open.
class TutorSettingsScreen extends ConsumerWidget {
  const TutorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final voiceOn = ref.watch(tutorVoiceRepliesProvider);
    final mentor =
        ref.watch(teacherSupportModeProvider) == TeacherSupportMode.mentor;
    final session = ref.watch(tutorSessionProvider);
    final choice = ref.watch(teachingChoiceProvider);

    // NOT transparent: this is a pushed route, so there is no shell canvas
    // behind it — transparency exposed the black window behind the app bar.
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpace.md),
          child: CircleIconButton(
            icon: Icons.arrow_back_rounded,
            size: 42,
            tooltip: 'Back',
            onTap: () => context.pop(),
          ),
        ),
        title: const Text('Tutor settings'),
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                const SectionHeader(title: 'Conversation'),
                const SizedBox(height: AppSpace.md),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: voiceOn,
                        onChanged: (v) => ref
                            .read(tutorVoiceRepliesProvider.notifier)
                            .state = v,
                        secondary: _iconChip(
                          tones,
                          voiceOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                        ),
                        title: Text('Voice replies', style: _title(tones)),
                        subtitle: Text(
                          'Speak each reply aloud automatically',
                          style: _sub(tones),
                        ),
                      ),
                      Divider(height: 1, color: tones.hairline),
                      SwitchListTile(
                        value: mentor,
                        onChanged: (v) => ref
                                .read(teacherSupportModeProvider.notifier)
                                .state =
                            v
                                ? TeacherSupportMode.mentor
                                : TeacherSupportMode.immersion,
                        secondary: _iconChip(
                          tones,
                          mentor ? Icons.school_outlined : Icons.public,
                        ),
                        title: Text(
                          mentor ? 'Mentor mode' : 'Immersion mode',
                          style: _title(tones),
                        ),
                        subtitle: Text(
                          mentor
                              ? 'Shows English support under Spanish replies'
                              : 'Spanish only — no English shown',
                          style: _sub(tones),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Voice & models'),
                const SizedBox(height: AppSpace.md),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _link(
                        context,
                        tones,
                        icon: Icons.graphic_eq_rounded,
                        title: 'Voice settings',
                        subtitle: 'Engine, speed, offline voices',
                        route: '/voice-settings',
                      ),
                      Divider(height: 1, color: tones.hairline),
                      _link(
                        context,
                        tones,
                        icon: Icons.psychology_outlined,
                        title: 'AI model',
                        subtitle: 'On-device language model',
                        route: '/llm-settings',
                      ),
                      Divider(height: 1, color: tones.hairline),
                      _link(
                        context,
                        tones,
                        icon: Icons.mic_none_rounded,
                        title: 'Speech recognition',
                        subtitle: 'Offline listening model',
                        route: '/whisper-settings',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                // Teaching state — visible on request, not on every open.
                const SectionHeader(title: 'What your teacher is working on'),
                const SizedBox(height: AppSpace.md),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session != null) ...[
                        _fact(
                          tones,
                          Icons.school,
                          'Teaching approach',
                          _modeLabel(session.mode.name),
                        ),
                        if (session.context.focusConcept != null)
                          _fact(
                            tones,
                            Icons.center_focus_strong,
                            'Current focus',
                            session.context.focusConcept!.name,
                          ),
                        _fact(
                          tones,
                          Icons.lightbulb_outline,
                          'Misconceptions in context',
                          '${session.context.misconceptions.length}',
                        ),
                      ] else if (choice != null) ...[
                        _fact(
                          tones,
                          Icons.school,
                          'Next lesson',
                          choice.rationale,
                        ),
                      ] else
                        Text(
                          'Start a conversation and your teacher’s plan '
                          'will appear here.',
                          style: _sub(tones),
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

  static TextStyle _title(AppTones tones) => TextStyle(
        color: tones.ink,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle _sub(AppTones tones) =>
      TextStyle(color: tones.inkSoft, fontSize: 13, height: 1.35);

  static String _modeLabel(String name) =>
      name[0].toUpperCase() + name.substring(1);

  Widget _iconChip(AppTones tones, IconData icon) => Container(
        width: 40,
        height: 40,
        decoration:
            BoxDecoration(color: tones.cardMuted, shape: BoxShape.circle),
        child: Icon(icon, size: 19, color: tones.ink),
      );

  Widget _link(
    BuildContext context,
    AppTones tones, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) =>
      ListTile(
        leading: _iconChip(tones, icon),
        title: Text(title, style: _title(tones)),
        subtitle: Text(subtitle, style: _sub(tones)),
        trailing: Icon(Icons.chevron_right_rounded, color: tones.inkSoft),
        onTap: () => context.push(route),
      );

  Widget _fact(AppTones tones, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tones.inkSoft),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: tones.inkSoft, fontSize: 12.5)),
                  Text(value, style: _title(tones)),
                ],
              ),
            ),
          ],
        ),
      );
}
