import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/admin_studio_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/language_concept_screen.dart';
import 'screens/language_dashboard_screen.dart';
import 'screens/language_practice_screen.dart';
import 'screens/language_tutor_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mock_exam_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/practice_setup_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.value;
      final signedIn = user != null;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn && !onLogin) return '/login';
      if (signedIn && onLogin) return '/';
      // UI gate only; production enforcement is custom claims + rules.
      if (state.matchedLocation.startsWith('/admin') &&
          !(user?.isAdmin ?? false)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(
        path: '/practice',
        builder: (_, _) => const PracticeSetupScreen(),
      ),
      GoRoute(
        path: '/practice/session',
        builder: (_, _) => const PracticeScreen(),
      ),
      GoRoute(path: '/exam', builder: (_, _) => const MockExamScreen()),
      GoRoute(path: '/bookmarks', builder: (_, _) => const BookmarksScreen()),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/language',
        builder: (_, _) => const LanguageDashboardScreen(),
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
      GoRoute(path: '/admin', builder: (_, _) => const AdminStudioScreen()),
    ],
  );
});
