import 'package:flutter/material.dart';

/// Constrains content width on wide layouts (web/tablet).
class CenteredBody extends StatelessWidget {
  const CenteredBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }
}
