/// Riverpod wiring for app-level state: auth, theme, onboarding, and the
/// study store (settings "clear data"). Exam-era session controllers and
/// content-studio providers were removed in the tech-debt sweep; the
/// language platform wires its own state in `language_providers.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/models.dart';
import '../domain/repositories.dart';
import '../infrastructure/demo_repositories.dart';

// ---------- repositories (swap point for Firestore implementations) ----------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DemoAuthRepository(),
);

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => DemoStudyRepository(),
);

// ---------- app state ----------

final authStateProvider = StreamProvider<UserProfile?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// First-run onboarding gate (in-memory demo; persists to a real store on
/// the Firestore swap). False → the router shows the onboarding flow once.
final onboardingSeenProvider = StateProvider<bool>((ref) => false);
