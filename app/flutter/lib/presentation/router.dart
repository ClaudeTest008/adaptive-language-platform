import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/home_shell.dart';
import 'screens/language_concept_screen.dart';
import 'screens/language_content_screen.dart';
import 'screens/language_goals_screen.dart';
import 'screens/language_onboarding_screen.dart';
import 'screens/language_practice_screen.dart';
import 'screens/language_story_reader_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tutor_settings_screen.dart';
import 'screens/voice_settings_screen.dart';
import 'screens/llm_settings_screen.dart';
import 'screens/whisper_settings_screen.dart';
import 'ui.dart';

/// Shared-axis-style page: a fade combined with a gentle scale/rise, for a
/// premium push transition on secondary routes.
CustomTransitionPage<void> _fadeThrough(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: Transform.scale(
          scale: 0.98 + 0.02 * curved.value,
          child: child,
        ),
      );
    },
  );
}

/// Language-first navigation (ADR-0019/0021): the Language Lab IS the app,
/// now a bottom-nav shell (Lab / Stories / Speaking / Tutor). Exam-era
/// screens are retired; their code remains until the package rename sweep.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingSeen = ref.watch(onboardingSeenProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final signedIn = authState.value != null;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onOnboarding = loc == '/onboarding';
      if (!signedIn) return onLogin ? null : '/login';
      // Signed in: first run goes through onboarding once.
      if (!onboardingSeen && !onOnboarding) return '/onboarding';
      if (onboardingSeen && onOnboarding) return '/';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const LanguageOnboardingScreen(),
      ),
      GoRoute(path: '/', builder: (_, _) => const HomeShell()),
      // Legacy deep links → the shell (tabs handle the rest).
      GoRoute(path: '/language', redirect: (_, _) => '/'),
      GoRoute(path: '/language/tutor', redirect: (_, _) => '/'),
      GoRoute(
        path: '/language/practice',
        pageBuilder: (_, state) => _fadeThrough(
          LanguagePracticeScreen(
            focus: (state.extra as List<String>?) ?? const [],
          ),
        ),
      ),
      GoRoute(
        path: '/language/concept/:id',
        // go_router already URL-decodes path parameters.
        pageBuilder: (_, state) => _fadeThrough(
          LanguageConceptScreen(conceptId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/story/:id',
        pageBuilder: (_, state) => _fadeThrough(
          LanguageStoryReaderScreen(storyId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, _) => _fadeThrough(const SettingsScreen()),
      ),
      GoRoute(
        path: '/content',
        pageBuilder: (_, _) => _fadeThrough(const LanguageContentScreen()),
      ),
      GoRoute(
        path: '/goals',
        pageBuilder: (_, _) => _fadeThrough(const LanguageGoalsScreen()),
      ),
      GoRoute(
        path: '/whisper-settings',
        pageBuilder: (_, _) => _fadeThrough(const WhisperSettingsScreen()),
      ),
      GoRoute(
        path: '/llm-settings',
        pageBuilder: (_, _) => _fadeThrough(const LlmSettingsScreen()),
      ),
      GoRoute(
        path: '/tutor-settings',
        pageBuilder: (_, _) => _fadeThrough(const TutorSettingsScreen()),
      ),
      GoRoute(
        path: '/voice-settings',
        pageBuilder: (_, _) => _fadeThrough(const VoiceSettingsScreen()),
      ),
    ],
  );
});
