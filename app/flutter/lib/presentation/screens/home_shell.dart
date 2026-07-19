import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../ui.dart';
import 'language_dashboard_screen.dart';
import 'language_speaking_screen.dart';
import 'language_stories_screen.dart';
import 'language_tutor_screen.dart';

/// Selected home tab. A StateProvider so any widget (e.g. the dashboard
/// tutor hero) can switch tabs without prop drilling.
final homeTabProvider = StateProvider<int>((ref) => 0);

/// App shell (ADR-0021): bottom NavigationBar over the four learner
/// surfaces. Replaces the floating action button; the keyboard now
/// appears only when a text field is focused (standard behavior).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [
    LanguageDashboardScreen(),
    LanguageStoriesScreen(),
    LanguageSpeakingScreen(),
    LanguageTutorScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);
    final tones = AppTones.of(context);
    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tones.hairline)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(homeTabProvider.notifier).state = i,
          destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Speaking',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Tutor',
          ),
          ],
        ),
      ),
    );
  }
}
