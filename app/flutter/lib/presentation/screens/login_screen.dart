import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../ui.dart';
import '../widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_registering) {
        await auth.register(
          displayName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signIn(email: _email.text.trim(), password: _password.text);
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// DEBUG BUILDS ONLY: one-tap test account so device verification never
  /// repeats manual registration. `kDebugMode` is a compile-time constant —
  /// in release builds this method and its button are tree-shaken out
  /// entirely; it can never ship. It uses the normal demo auth repository
  /// (register → auto sign-in; falls back to sign-in when the account
  /// already exists this run). No production credentials involved.
  Future<void> _devLogin() async {
    if (!kDebugMode) return;
    setState(() => _busy = true);
    final auth = ref.read(authRepositoryProvider);
    const email = 'dev@test.local';
    const password = 'devtest123';
    try {
      await auth.register(
        displayName: 'Dev',
        email: email,
        password: password,
      );
    } on Exception {
      try {
        await auth.signIn(email: email, password: password);
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first.')),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  /// Pill-shaped input in the design-system's recessed fill.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
    void Function(String)? onSubmitted,
  }) {
    return Builder(
      builder: (context) {
        final tones = AppTones.of(context);
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(color: tones.ink, fontSize: 15.5),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: tones.inkSoft),
            filled: true,
            fillColor: tones.cardMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg + 2,
              vertical: AppSpace.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: tones.ink, width: 1.5),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphericBackground(
        child: CenteredBody(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const SizedBox(height: AppSpace.xxl),
                  FadeInUp(
                    child: Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tones.tint(AppTint.sun),
                        ),
                        child: Icon(
                          Icons.language,
                          size: 38,
                          color: tones.onTint(AppTint.sun),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Adaptive Language Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tones.ink,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Your personal AI language teacher — Demo Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tones.inkSoft, fontSize: 13.5),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  SoftCard(
                    padding: const EdgeInsets.all(AppSpace.lg + 2),
                    child: Column(
                      children: [
                        if (_registering) ...[
                          _field(
                            controller: _name,
                            label: 'Display name',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],
                        _field(
                          controller: _email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: AppSpace.md),
                        _field(
                          controller: _password,
                          label: 'Password',
                          obscure: true,
                          validator: (v) => (v == null || v.length < 8)
                              ? 'At least 8 characters'
                              : null,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        PrimaryButton(
                          label: _registering ? 'Create account' : 'Sign in',
                          onPressed: _busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextButton(
                    onPressed: () =>
                        setState(() => _registering = !_registering),
                    style: TextButton.styleFrom(foregroundColor: tones.ink),
                    child: Text(
                      _registering
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!_registering)
                    TextButton(
                      onPressed: _forgotPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: tones.inkSoft,
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  // Compile-time gate: this button does not exist in release.
                  if (kDebugMode)
                    TextButton(
                      key: const Key('devLogin'),
                      onPressed: _busy ? null : _devLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: tones.inkSoft,
                      ),
                      child: const Text('Dev login (debug only)'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
