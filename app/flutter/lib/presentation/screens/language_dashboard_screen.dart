import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/lesson.dart';
import '../language_providers.dart';

/// Phase 2 showcase: per-skill mastery, misconception "Teacher Notes",
/// and today's lesson preview — all driven live by the language layer
/// over the unchanged core engine.
class LanguageDashboardScreen extends ConsumerWidget {
  const LanguageDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);
    final learner = ref.watch(languageLearnerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (curriculumAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Language Lab')),
        body: Center(child: Text('Curriculum failed to load:\n'
            '${curriculumAsync.error}')),
      );
    }
    final curriculum = curriculumAsync.value;
    if (curriculum == null || !learner.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Language Lab')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                languageName: curriculum.languageName,
                level: 'A1 · CEFR',
                answered: learner.model.totalAnswered,
                accuracy: learner.model.overallAccuracy,
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                icon: Icons.insights,
                title: 'Skill mastery',
                subtitle: 'Each skill tracked independently',
              ),
              const _SkillMasteryCard(),
              const SizedBox(height: 16),
              _SectionHeader(
                icon: Icons.school,
                title: 'Teacher notes',
                subtitle: 'Interference from English, explained',
              ),
              const _TeacherNotesCard(),
              const SizedBox(height: 16),
              _SectionHeader(
                icon: Icons.today,
                title: "Today's lesson",
                subtitle: 'Misconception repair first',
              ),
              const _LessonPreviewCard(),
              const SizedBox(height: 24),
              Text(
                'Demo learner · answers simulated through the adaptive core · '
                'tap a note or lesson block to inspect the concept',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.languageName,
    required this.level,
    required this.answered,
    required this.accuracy,
  });

  final String languageName;
  final String level;
  final int answered;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primaryContainer, scheme.tertiaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primary,
              child: Text(
                '🇪🇸',
                style: text.headlineSmall,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: text.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    level,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$answered',
                  style: text.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'answers · ${(accuracy * 100).round()}% correct',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Text(title, style: text.titleMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillMasteryCard extends ConsumerWidget {
  const _SkillMasteryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mastery = ref.watch(languageSkillMasteryProvider);
    if (mastery.isEmpty) return const SizedBox.shrink();
    final ordered = mastery.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final e in ordered)
              _SkillBar(skill: e.key, value: e.value),
          ],
        ),
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.skill, required this.value});

  final LanguageSkill skill;
  final double value;

  static const _icons = {
    LanguageSkill.vocabulary: Icons.style,
    LanguageSkill.grammar: Icons.account_tree,
    LanguageSkill.reading: Icons.menu_book,
    LanguageSkill.writing: Icons.edit_note,
    LanguageSkill.listening: Icons.headphones,
    LanguageSkill.speaking: Icons.record_voice_over,
    LanguageSkill.pronunciation: Icons.graphic_eq,
    LanguageSkill.conversation: Icons.forum,
    LanguageSkill.culture: Icons.public,
    LanguageSkill.comprehension: Icons.psychology,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = value >= 0.7
        ? scheme.primary
        : value >= 0.4
        ? scheme.tertiary
        : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_icons[skill], size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              skill.name[0].toUpperCase() + skill.name.substring(1),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  color: color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Misconception insights: what interferes, why, and what to practice.
class _TeacherNotesCard extends ConsumerWidget {
  const _TeacherNotesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(languageLearnerProvider);
    final curriculum = ref.watch(curriculumProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final notes = learner.misconceptions.all;
    if (notes.isEmpty || curriculum == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No misconceptions detected — keep going!'),
        ),
      );
    }
    return Column(
      children: [
        for (final m in notes.take(4))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(
                '/language/concept/${Uri.encodeComponent(m.conceptId)}',
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          m.relationType == null
                              ? Icons.sync_problem
                              : m.relationType!.name == 'falseFriend'
                              ? Icons.compare_arrows
                              : Icons.translate,
                          size: 18,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            curriculum.graph[m.conceptId]?.name ?? m.conceptId,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _Pill(
                          label: '${m.occurrences}×',
                          color: scheme.errorContainer,
                          textColor: scheme.onErrorContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(m.explanation),
                    if (m.relatedConceptIds.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final id in m.relatedConceptIds.take(5))
                            _Pill(
                              label: curriculum.graph[id]?.name ??
                                  id.split(':').last,
                              color: scheme.secondaryContainer,
                              textColor: scheme.onSecondaryContainer,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}

class _LessonPreviewCard extends ConsumerWidget {
  const _LessonPreviewCard();

  static const _kindIcons = {
    LessonBlockKind.repair: Icons.build_circle,
    LessonBlockKind.review: Icons.refresh,
    LessonBlockKind.practice: Icons.fitness_center,
    LessonBlockKind.conversation: Icons.forum,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(lessonPreviewProvider);
    final scheme = Theme.of(context).colorScheme;
    if (blocks.isEmpty) return const SizedBox.shrink();
    final total = blocks.fold(0, (sum, b) => sum + b.minutes);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$total minutes today',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            for (final (i, b) in blocks.indexed) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: b.kind == LessonBlockKind.repair
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    child: Icon(
                      _kindIcons[b.kind],
                      size: 18,
                      color: b.kind == LessonBlockKind.repair
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '${b.minutes} min · ${b.kind.name}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < blocks.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: SizedBox(
                    height: 16,
                    child: VerticalDivider(
                      width: 2,
                      color: scheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
