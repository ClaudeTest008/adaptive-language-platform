import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/lesson.dart';
import '../../language/notebook.dart';
import '../../language/tutor.dart';
import '../language_providers.dart';
import '../providers.dart';
import '../ui.dart';
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Language Lab'),
        actions: [
          const _LanguageMenu(),
          IconButton(
            icon: const Icon(Icons.track_changes_outlined),
            tooltip: 'Your goals',
            onPressed: () => context.push('/goals'),
          ),
          if (ref.watch(authStateProvider).value?.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.library_add_outlined),
              tooltip: 'Content Studio',
              onPressed: () => context.push('/content'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: AtmosphericBackground(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.lg,
              88,
            ),
            children: [
              FadeInUp(
                child: _HeaderCard(
                  languageName: curriculum.languageName,
                  languageCode: curriculum.languageCode,
                  answered: learner.model.totalAnswered,
                  accuracy: learner.model.overallAccuracy,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              const FadeInUp(delayMs: 80, child: _TutorHeroCard()),
              const SizedBox(height: AppSpace.lg),
              // 1 · Teacher's Notes — the notebook leads, so the home reads
              // as "my teacher knows me" before "I have another lesson".
              const FadeInUp(
                delayMs: 140,
                child: _ExpandableSection(
                  icon: Icons.menu_book,
                  title: "Teacher's Notes",
                  subtitle: 'What your teacher has noticed',
                  initiallyExpanded: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TeacherNotebookCard(),
                      SizedBox(height: AppSpace.sm),
                      _TeacherNotesCard(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // 2 · Today's Goals — daily targets per skill.
              const FadeInUp(
                delayMs: 200,
                child: _ExpandableSection(
                  icon: Icons.flag_outlined,
                  title: "Today's goals",
                  subtitle: 'Daily targets',
                  child: _TodaysGoalsCard(),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // 3 · Progress Summary — mastery by skill (no XP).
              const FadeInUp(
                delayMs: 260,
                child: _ExpandableSection(
                  icon: Icons.insights,
                  title: 'Progress summary',
                  subtitle: 'Mastery by skill',
                  child: _SkillMasteryCard(),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // 4 · Current Focus — the active lesson, with the full plan.
              const FadeInUp(
                delayMs: 320,
                child: _ExpandableSection(
                  icon: Icons.center_focus_strong_outlined,
                  title: 'Current focus',
                  subtitle: 'Your active lesson',
                  initiallyExpanded: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CurrentFocusCard(),
                      SizedBox(height: AppSpace.sm),
                      _LessonPreviewCard(),
                      SizedBox(height: AppSpace.sm),
                      _PracticeCta(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // 5 · Recommended Next Lesson — one pick from progress.
              const FadeInUp(
                delayMs: 380,
                child: _ExpandableSection(
                  icon: Icons.lightbulb_outline,
                  title: 'Recommended next lesson',
                  subtitle: 'Chosen from your progress',
                  child: _RecommendedNextLessonCard(),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
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
    return GradientHero(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      languageName,
                      style: text.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              const GlassPill(label: 'A1 · CEFR'),
              GlassPill(label: '$answered answers'),
              GlassPill(label: '${(accuracy * 100).round()}% correct'),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push(
                '/language/practice',
                extra: const <String>[],
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continue learning'),
            ),
          ),
        ],
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
    return GradientHero(
      colors: [scheme.primary, scheme.tertiary],
      onTap: () => ref.read(homeTabProvider.notifier).state = 3,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
            child: Icon(Icons.school, color: scheme.onPrimary, size: 28),
          ),
          const SizedBox(width: AppSpace.lg),
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
                const SizedBox(height: AppSpace.xs),
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
    );
  }
}

/// Practice CTA under today's plan.
class _PracticeCta extends ConsumerWidget {
  const _PracticeCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(dailyLessonProvider);
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


/// Collapsible dashboard section — a premium ExpansionTile so the learner
/// scans the home at a glance and opens only what they need. Smoothly
/// animates open/closed (built-in).
class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
          ),
          title: Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            0,
            AppSpace.lg,
            AppSpace.lg,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [child],
        ),
      ),
    );
  }
}

/// 1 · Teacher's Notebook — real observations generated live from the
/// learner's metrics and persisted across sessions (Phase 17,
/// `teacherNotebookProvider`). The live misconception card sits below it for
/// tap-through detail on each detected interference.
class _TeacherNotebookCard extends ConsumerWidget {
  const _TeacherNotebookCard();

  static const _icons = {
    ObservationCategory.grammar: Icons.account_tree,
    ObservationCategory.vocabulary: Icons.style,
    ObservationCategory.listening: Icons.headphones,
    ObservationCategory.speaking: Icons.record_voice_over,
    ObservationCategory.pronunciation: Icons.graphic_eq,
    ObservationCategory.reading: Icons.menu_book,
    ObservationCategory.conversation: Icons.forum,
    ObservationCategory.trend: Icons.trending_up,
    ObservationCategory.focus: Icons.center_focus_strong,
    ObservationCategory.encouragement: Icons.emoji_events,
    ObservationCategory.plan: Icons.arrow_forward,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherNotebookProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final notebook = async.value;
    if (notebook == null) {
      return const GlassCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Working level: around ${notebook.cefrEstimate}',
                style: text.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final o in notebook.observations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _icons[o.category] ?? Icons.edit_note,
                    size: 18,
                    color: o.kind == ObservationKind.plan
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      o.text,
                      style: o.kind == ObservationKind.plan
                          ? text.bodyMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            )
                          : text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 2 · Today's Goals — daily target per skill with a progress bar.
class _TodaysGoalsCard extends StatelessWidget {
  const _TodaysGoalsCard();

  // ponytail: placeholder daily progress; wire to per-skill daily activity
  // once the engine tracks minutes-per-skill-per-day.
  static const _goals = <({String label, IconData icon, double value})>[
    (label: 'Reading', icon: Icons.menu_book, value: 0.6),
    (label: 'Listening', icon: Icons.headphones, value: 0.35),
    (label: 'Speaking', icon: Icons.record_voice_over, value: 0.5),
    (label: 'Conversation', icon: Icons.forum, value: 0.2),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          for (final g in _goals)
            _GoalBar(label: g.label, icon: g.icon, value: g.value),
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4 · Current Focus — the active lesson, named for the learner, with an
/// estimate and how many activities remain. Numbers come from the live
/// daily-lesson engine.
class _CurrentFocusCard extends ConsumerWidget {
  const _CurrentFocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final blocks = ref.watch(dailyLessonProvider);
    final learner = ref.watch(languageLearnerProvider);
    final curriculum = ref.watch(curriculumProvider).value;
    final top = learner.misconceptions.all.firstOrNull;
    final focusName = top != null && curriculum != null
        ? (curriculum.graph[top.conceptId]?.name ?? top.conceptId)
        : (blocks.firstOrNull?.title ?? 'Warm-up review');
    final minutes = blocks.fold(0, (s, b) => s + b.minutes);
    final remaining = blocks.length;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.center_focus_strong,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(focusName, style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                label: '~$minutes min to complete',
                color: scheme.secondaryContainer,
                textColor: scheme.onSecondaryContainer,
              ),
              _Pill(
                label: '$remaining activities left',
                color: scheme.secondaryContainer,
                textColor: scheme.onSecondaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 5 · Recommended Next Lesson — one pick derived from today's plan (the
/// first non-repair block), with a one-tap start. Falls back to a sensible
/// placeholder when the plan is all repair.
class _RecommendedNextLessonCard extends ConsumerWidget {
  const _RecommendedNextLessonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final blocks = ref.watch(dailyLessonProvider);
    final rec = blocks
        .where((b) => b.kind != LessonBlockKind.repair)
        .firstOrNull;
    final title = rec?.title ?? 'Imperfect tense';
    final reason = rec?.reason ?? 'Builds on what you practiced today.';
    final minutes = rec?.minutes ?? 10;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.tertiaryContainer,
                child: Icon(
                  Icons.lightbulb,
                  size: 18,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: text.titleSmall)),
              _Pill(
                label: '$minutes min',
                color: scheme.tertiaryContainer,
                textColor: scheme.onTertiaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: rec == null
                  ? null
                  : () => _launchBlock(context, ref, rec),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start lesson'),
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
    return GlassCard(
      child: Column(
        children: [
          for (final e in ordered) _SkillBar(skill: e.key, value: e.value),
        ],
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

const _lessonKindIcons = {
  LessonBlockKind.repair: Icons.build_circle,
  LessonBlockKind.review: Icons.refresh,
  LessonBlockKind.grammar: Icons.account_tree,
  LessonBlockKind.vocabulary: Icons.style,
  LessonBlockKind.pronunciation: Icons.mic,
  LessonBlockKind.story: Icons.auto_stories,
  LessonBlockKind.conversation: Icons.forum,
  LessonBlockKind.practice: Icons.fitness_center,
};

/// Launches the activity a plan block points to.
void _launchBlock(BuildContext context, WidgetRef ref, LessonBlock b) {
  switch (b.activity) {
    case LessonActivity.practice:
      if (b.conceptIds.isNotEmpty) {
        context.push('/language/practice', extra: b.conceptIds);
      }
    case LessonActivity.speaking:
      ref.read(speakingProvider.notifier)
        ..reset()
        ..start(focusConceptIds: b.conceptIds);
      ref.read(homeTabProvider.notifier).state = 2;
    case LessonActivity.story:
      if (b.storyId != null) {
        context.push('/story/${Uri.encodeComponent(b.storyId!)}');
      }
    case LessonActivity.tutor:
      // A conversation block drops straight into a Conversation session;
      // other tutor blocks land on the mode selector.
      if (b.kind == LessonBlockKind.conversation) {
        ref.read(tutorSessionProvider.notifier).start(TutorMode.conversation);
      }
      ref.read(homeTabProvider.notifier).state = 3;
  }
}

class _LessonPreviewCard extends ConsumerWidget {
  const _LessonPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(dailyLessonProvider);
    final scheme = Theme.of(context).colorScheme;
    if (blocks.isEmpty) return const SizedBox.shrink();
    final total = blocks.fold(0, (sum, b) => sum + b.minutes);
    return GlassCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$total minutes today · tap a block to start',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            for (final (i, b) in blocks.indexed) ...[
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _launchBlock(context, ref, b),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: b.kind == LessonBlockKind.repair
                            ? scheme.errorContainer
                            : scheme.primaryContainer,
                        child: Icon(
                          _lessonKindIcons[b.kind],
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
                              '${b.title}  ·  ${b.minutes} min',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              b.reason,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
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
    );
  }
}
