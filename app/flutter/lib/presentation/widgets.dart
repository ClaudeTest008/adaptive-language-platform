import 'package:flutter/material.dart';

/// Answer option tile with feedback colors once answered.
class AnswerTile extends StatelessWidget {
  const AnswerTile({
    super.key,
    required this.text,
    required this.index,
    required this.onTap,
    this.selectedIndex,
    this.correctIndex,
  });

  final String text;
  final int index;
  final VoidCallback? onTap;

  /// User's selection, if answered.
  final int? selectedIndex;

  /// Revealed correct index, if answered.
  final int? correctIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answered = selectedIndex != null;

    Color? tileColor;
    IconData? icon;
    if (answered && correctIndex != null) {
      if (index == correctIndex) {
        tileColor = Colors.green.withValues(alpha: 0.15);
        icon = Icons.check_circle;
      } else if (index == selectedIndex) {
        tileColor = scheme.errorContainer;
        icon = Icons.cancel;
      }
    } else if (answered && index == selectedIndex) {
      tileColor = scheme.primaryContainer;
    }

    return Card(
      color: tileColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 14,
          child: Text(
            String.fromCharCode(65 + index),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        title: Text(text),
        trailing: icon == null
            ? null
            : Icon(
                icon,
                color: index == correctIndex ? Colors.green : scheme.error,
              ),
      ),
    );
  }
}

class ExplanationCard extends StatelessWidget {
  const ExplanationCard({super.key, required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                explanation,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

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
