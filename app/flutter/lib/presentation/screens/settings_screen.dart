import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (v) => ref.read(themeModeProvider.notifier).state = v!,
              child: const Column(
                children: [
                  RadioListTile(value: ThemeMode.system, title: Text('System')),
                  RadioListTile(value: ThemeMode.light, title: Text('Light')),
                  RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
                ],
              ),
            ),
            const Divider(height: 32),
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete account',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(studyRepositoryProvider).clearAll();
                  await ref.read(authRepositoryProvider).deleteAccount();
                }
              },
            ),
            const Divider(height: 32),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About'),
              subtitle: Text(
                'Exam Prep v0.1.0 — demo mode (in-memory data). '
                'Firebase backend connects in a later milestone.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
