import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers.dart';
import 'presentation/router.dart';
import 'presentation/ui.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Adaptive Language Platform',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// One theme builder for both brightnesses, driven by the same [AppTones]
/// the widgets read — so Material defaults (buttons, inputs, nav bar) land
/// on the design palette instead of a seeded approximation of it.
ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  // Mirrors AppTones; ColorScheme exists for Material's own components.
  const lightInk = Color(0xFF1B1E28);
  final canvas = dark ? const Color(0xFF111217) : const Color(0xFFF7F3E9);
  final card = dark ? const Color(0xFF1E212A) : Colors.white;
  final muted = dark ? const Color(0xFF262A34) : const Color(0xFFEDE8DC);
  final ink = dark ? const Color(0xFFF4F5F7) : lightInk;
  final inkSoft = dark ? const Color(0xFF9AA0AE) : const Color(0xFF6B6E7A);
  final accent = dark ? const Color(0xFFF5CE47) : lightInk;
  final onAccent = dark ? lightInk : Colors.white;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: dark ? const Color(0xFF3A331C) : const Color(0xFFC3C4F7),
    onPrimaryContainer: dark ? const Color(0xFFF7E9B8) : lightInk,
    secondary: const Color(0xFF2E9E74),
    onSecondary: Colors.white,
    secondaryContainer:
        dark ? const Color(0xFF1F3330) : const Color(0xFFC9E2D6),
    onSecondaryContainer: dark ? const Color(0xFFCDEBDD) : lightInk,
    tertiary: const Color(0xFF6C6CE5),
    onTertiary: Colors.white,
    tertiaryContainer: dark ? const Color(0xFF272741) : const Color(0xFFDCDCC0),
    onTertiaryContainer: dark ? const Color(0xFFDDDDF7) : lightInk,
    error: const Color(0xFFD1425A),
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF3A1D24) : const Color(0xFFF9DDE1),
    onErrorContainer: dark ? const Color(0xFFF7C9D1) : const Color(0xFF5A1522),
    surface: canvas,
    onSurface: ink,
    onSurfaceVariant: inkSoft,
    surfaceContainerLowest: dark ? const Color(0xFF0C0D11) : Colors.white,
    surfaceContainerLow: card,
    surfaceContainer: dark ? const Color(0xFF22252E) : const Color(0xFFF2EDE1),
    surfaceContainerHigh: muted,
    surfaceContainerHighest:
        dark ? const Color(0xFF2C303B) : const Color(0xFFE6E0D2),
    outline: dark ? const Color(0xFF3A3F4B) : const Color(0xFFD8D2C4),
    outlineVariant: dark ? const Color(0xFF2A2E38) : const Color(0xFFE6E0D2),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: dark ? const Color(0xFFF4F5F7) : lightInk,
    onInverseSurface: dark ? lightInk : Colors.white,
    inversePrimary: dark ? lightInk : const Color(0xFFF5CE47),
  );

  final baseText = Typography.material2021(colorScheme: scheme)
      .black
      .apply(bodyColor: ink, displayColor: ink);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    // Display type is large, tight and confident (mockup headlines); body
    // keeps a roomy line-height for calm reading.
    textTheme: baseText.copyWith(
      displaySmall: baseText.displaySmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.2),
      headlineMedium: baseText.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.9),
      headlineSmall: baseText.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleLarge: baseText.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: baseText.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide.none,
      backgroundColor: muted,
      selectedColor: accent,
      labelStyle: TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 6),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: dark ? const Color(0xFF171921) : const Color(0xFFF1EBDC),
      surfaceTintColor: Colors.transparent,
      indicatorColor: dark ? const Color(0xFF2C303B) : Colors.white,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? ink : inkSoft,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? ink : inkSoft,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        textStyle: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(0, 50),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? const Color(0xFFF5CE47) : const Color(0xFF3A3F72),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: ink),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      iconColor: inkSoft,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: dark ? const Color(0xFFF5CE47) : const Color(0xFF2E9E74),
      linearMinHeight: 8,
      linearTrackColor: muted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: muted,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: muted,
        foregroundColor: ink,
        selectedBackgroundColor: dark ? const Color(0xFF3A3F4B) : Colors.white,
        selectedForegroundColor: ink,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1E212A) : Colors.white,
      hintStyle: TextStyle(color: inkSoft, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg + 2,
        vertical: AppSpace.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: ink.withValues(alpha: 0.55)),
      ),
    ),
  );
}
