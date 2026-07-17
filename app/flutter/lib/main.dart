import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers.dart';
import 'presentation/router.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Immersion palette: deep teal seed → teal/blue/green M3 scheme.
    const seed = Color(0xFF00897B);
    ThemeData themed(Brightness brightness) {
      final scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      );
      return ThemeData(
        colorScheme: scheme,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: scheme.surfaceContainerLow,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide.none,
          backgroundColor: scheme.surfaceContainerHigh,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: scheme.surface,
          titleTextStyle: TextStyle(
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        // Clean, premium bottom nav: pill indicator, labels only when
        // selected, flat surface that blends with the page.
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          elevation: 0,
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Adaptive Language Platform',
      debugShowCheckedModeBanner: false,
      theme: themed(Brightness.light),
      darkTheme: themed(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
