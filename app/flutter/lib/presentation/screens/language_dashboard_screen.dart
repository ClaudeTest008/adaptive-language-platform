import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/lesson.dart';
import '../language_providers.dart';
import 'home_shell.dart';

/// Language Lab — the app's home (ADR-0019). Everything the vision
/// promises, driven live: AI tutor hero, today's personalized plan,
/// independent per-skill mastery, misconception Teacher Notes.
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
      appBar: AppBar(
        title: const Text('Language Lab'),
        actions: [
          const _LanguageMenu(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              _HeaderCard(
                languageName: curriculum.languageName,
                languageCode: curriculum.languageCode,
                answered: learner.model.totalAnswered,
                accuracy: learner.model.overallAccuracy,
              ),
              const SizedBox(height: 12),
              const _TutorHeroCard(),
              const SizedBox(height: 16),
              _SectionHeader(
                icon: Icons.today,
                title: "Today's plan",
                subtitle: 'Personalized · misconception repair first',
              ),
              const _LessonPreviewCard(),
              const SizedBox(height: 8),
              const _PracticeCta(),
              const SizedBox(height: 8),
              const _StoryRecommendation(),
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
                subtitle: 'Interference from your native language',
              ),
              const _TeacherNotesCard(),
              const SizedBox(height: 24),
              Text(
                'Demo learner · every number comes from the live adaptive '
                'engine · tap anything to dig in',
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

/// Target-language switcher — a new language is one curriculum JSON away.
class _LanguageMenu extends ConsumerWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLanguageProvider);
    final current = availableLanguages.firstWhere((l) => l.code == selected);
    return PopupMenuButton<String>(
      tooltip: 'Switch language',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(current.flag, style: const TextStyle(fontSize: 20)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      onSelected: (code) =>
          ref.read(selectedLanguageProvider.notifier).state = code,
      itemBuilder: (context) => [
        for (final l in availableLanguages)
          PopupMenuItem(
            value: l.code,
            child: Row(
              children: [
                Text(l.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(l.name),
                if (l.code == selected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.languageName,
    required this.languageCode,
    required this.answered,
    required this.accuracy,
  });

  final String languageName;
  final String languageCode;
  final int answered;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final flag = availableLanguages
        .firstWhere(
          (l) => l.code == languageCode,
          orElse: () => availableLanguages.first,
        )
        .flag;
    return Card(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.tertiaryContainer,
              scheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: text.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _GlassPill(label: 'A1 · CEFR'),
                      _GlassPill(label: '$answered answers'),
                      _GlassPill(
                        label: '${(accuracy * 100).round()}% correct',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted pill on the gradient header.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// The star of the app: your personal teacher, opening with the exact
/// misconception it plans to repair.
class _TutorHeroCard extends ConsumerWidget {
  const _TutorHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final learner = ref.watch(languageLearnerProvider);
    final curriculum = ref.watch(curriculumProvider).value;
    final top = learner.misconceptions.all.firstOrNull;
    return Card(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(homeTabProvider.notifier).state = 3,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                child: Icon(Icons.school, color: scheme.onPrimary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your AI teacher is ready',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      top == null || curriculum == null
                          ? 'Teacher · Conversation · Coach · Socratic · '
                                'Grammar · Immersion'
                          : 'Wants to clear up: '
                                '${curriculum.graph[top.conceptId]?.name ?? top.conceptId}',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Practice CTA under today's plan.
class _PracticeCta extends ConsumerWidget {
  const _PracticeCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(lessonPreviewProvider);
    final repair = blocks
        .where((b) => b.kind == LessonBlockKind.repair)
        .firstOrNull;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: Theme.of(context).textTheme.titleMedium,
        ),
        icon: const Icon(Icons.play_arrow),
        label: Text(
          repair == null ? 'Start practice' : 'Start practice — fix weak spots',
        ),
        onPressed: () => context.push(
          '/language/practice',
          extra: repair?.conceptIds ?? const <String>[],
        ),
      ),
    );
  }
}

/// Story recommendation inside Today's plan — reading at the learner's
/// level, one tap into the reader.
class _StoryRecommendation extends ConsumerWidget {
  const _StoryRecommendation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storiesProvider).value?.firstOrNull;
    if (story == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.auto_stories, color: scheme.onTertiaryContainer),
        title: Text('Read: ${story.title}',
            style: TextStyle(color: scheme.onTertiaryContainer)),
        subtitle: Text(
          '${story.level.name.toUpperCase()} · ${story.phrases.length} phrases · tap to read & listen',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: () => context.push('/story/${Uri.encodeComponent(story.id)}'),
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
            for (final e in ordered) _SkillBar(skill: e.key, value: e.value),
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
              borderRadius: BorderRadius.circular(16),
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
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.errorContainer,
                          child: Icon(
                            m.relationType == null
                                ? Icons.sync_problem
                                : m.relationType!.name == 'falseFriend'
                                ? Icons.compare_arrows
                                : Icons.translate,
                            size: 16,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                              label:
                                  curriculum.graph[id]?.name ??
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
              InkWell(
                borderRadius: BorderRadius.circular(12),
                // Tapping a block starts practice focused on its concepts.
                onTap: b.conceptIds.isEmpty
                    ? null
                    : () => context.push(
                        '/language/practice',
                        extra: b.conceptIds,
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
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
                      if (b.conceptIds.isNotEmpty)
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
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
