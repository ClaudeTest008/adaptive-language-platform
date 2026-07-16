import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/language_concept_screen.dart';
import 'screens/language_dashboard_screen.dart';
import 'screens/language_practice_screen.dart';
import 'screens/language_tutor_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';

/// Language-first navigation (ADR-0019): the Language Lab IS the app.
/// Exam-era screens (practice/mock/bookmarks/admin studio) are retired
/// from navigation; their code remains until the package rename sweep.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final signedIn = authState.value != null;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn && !onLogin) return '/login';
      if (signedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const LanguageDashboardScreen()),
      GoRoute(
        path: '/language',
        redirect: (_, _) => '/', // legacy deep links
      ),
      GoRoute(
        path: '/language/tutor',
        builder: (_, _) => const LanguageTutorScreen(),
      ),
      GoRoute(
        path: '/language/practice',
        builder: (_, state) => LanguagePracticeScreen(
          focus: (state.extra as List<String>?) ?? const [],
        ),
      ),
      GoRoute(
        path: '/language/concept/:id',
        // go_router already URL-decodes path parameters.
        builder: (_, state) => LanguageConceptScreen(
          conceptId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
