import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../ui.dart';
import '../widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final tones = AppTones.of(context);
    final error = Theme.of(context).colorScheme.error;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphericBackground(
        child: SafeArea(
          child: CenteredBody(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.xxl,
              ),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      size: 42,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: tones.ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Appearance'),
                const SizedBox(height: AppSpace.md),
                FadeInUp(
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpace.sm,
                      horizontal: AppSpace.sm,
                    ),
                    child: RadioGroup<ThemeMode>(
                      groupValue: mode,
                      onChanged: (v) =>
                          ref.read(themeModeProvider.notifier).state = v!,
                      child: Column(
                        children: [
                          for (final (value, label) in const [
                            (ThemeMode.system, 'System'),
                            (ThemeMode.light, 'Light'),
                            (ThemeMode.dark, 'Dark'),
                          ])
                            RadioListTile(
                              value: value,
                              activeColor: tones.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.tile),
                              ),
                              title: Text(
                                label,
                                style: TextStyle(
                                  color: tones.ink,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Account'),
                const SizedBox(height: AppSpace.md),
                FadeInUp(
                  delayMs: 80,
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpace.sm,
                      horizontal: AppSpace.sm,
                    ),
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.logout,
                          label: 'Sign out',
                          onTap: () =>
                              ref.read(authRepositoryProvider).signOut(),
                        ),
                        _Row(
                          icon: Icons.delete_forever,
                          label: 'Delete account',
                          color: error,
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete account?'),
                                content: const Text(
                                  'This permanently deletes your account and all study '
                                  'progress. This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await ref
                                  .read(studyRepositoryProvider)
                                  .clearAll();
                              await ref
                                  .read(authRepositoryProvider)
                                  .deleteAccount();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'About'),
                const SizedBox(height: AppSpace.md),
                FadeInUp(
                  delayMs: 160,
                  child: SoftCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: tones.inkSoft),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About',
                                style: TextStyle(
                                  color: tones.ink,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpace.xs),
                              Text(
                                'Adaptive Language Platform v0.1.0 — demo mode (in-memory '
                                'data). Firebase backend connects in a later milestone.',
                                style: TextStyle(
                                  color: tones.inkSoft,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

/// Card row: circular icon chip, label, chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final fg = color ?? tones.ink;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fg.withValues(alpha: 0.10),
        ),
        child: Icon(icon, size: 19, color: fg),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: tones.inkSoft),
    );
  }
}
