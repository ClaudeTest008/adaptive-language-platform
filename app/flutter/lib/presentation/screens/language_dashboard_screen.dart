import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/learning_journey_engine.dart';
import '../../language/lesson.dart';
import '../../language/notebook.dart';
import '../../language/recommendation_engine.dart';
import '../../language/roleplay_engine.dart';
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
    final tones = AppTones.of(context);

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
      body: AtmosphericBackground(
        child: SafeArea(
          bottom: false,
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
              const SizedBox(height: AppSpace.lg),
              const FadeInUp(delayMs: 60, child: _TutorHeroCard()),
              const SizedBox(height: AppSpace.xl),
              // Quick practice — the four ways in, one tap each.
              const FadeInUp(delayMs: 80, child: _QuickActions()),
              const SizedBox(height: AppSpace.xl),
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
              // 4b · What to focus on next — the ONE unified recommendation list
              // (Phase 32 engine, merged with Phase 33 reader recs + Phase 34
              // connection bridges) made visible for the first time. Read-only:
              // TeacherBrain stays the single source of truth; this only shows
              // what the engines already derived.
              const FadeInUp(
                delayMs: 350,
                child: _ExpandableSection(
                  icon: Icons.recommend_outlined,
                  title: 'What to focus on next',
                  subtitle: 'From your whole learning history',
                  child: _TeacherRecommendationsCard(),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // 4c · Learning journeys — the Phase 32 Journey Engine
              // (journeyReportsProvider) made visible: each engaged domain's
              // path with assessed health + progress. Read-only, derived.
              const FadeInUp(
                delayMs: 365,
                child: _ExpandableSection(
                  icon: Icons.route_outlined,
                  title: 'Your learning journeys',
                  subtitle: 'Where each path stands',
                  child: _JourneysCard(),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // 4d · Suggested practice scene — the Phase 30 Roleplay Engine
              // (roleplaySelectionProvider) made visible: the scene the teacher
              // would run now, with its rationale. Read-only preview.
              const FadeInUp(
                delayMs: 380,
                child: _ExpandableSection(
                  icon: Icons.theater_comedy_outlined,
                  title: 'Suggested practice scene',
                  subtitle: 'A roleplay picked for you',
                  child: _RoleplaySuggestionCard(),
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
                style: TextStyle(color: tones.inkSoft, fontSize: 12.5),
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

/// The four ways into practice, as the design's 2×2 tinted grid.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void tab(int i) => ref.read(homeTabProvider.notifier).state = i;
    final tiles = <Widget>[
      ActionCard(
        icon: Icons.mic_none_rounded,
        label: 'Voice',
        title: 'Practice speaking',
        tint: AppTint.sage,
        onTap: () => tab(2),
      ),
      ActionCard(
        icon: Icons.auto_stories_outlined,
        label: 'Reading',
        title: 'Open your library',
        tint: AppTint.sun,
        onTap: () => tab(1),
      ),
      ActionCard(
        icon: Icons.forum_outlined,
        label: 'Tutor',
        title: 'Talk with your teacher',
        tint: AppTint.mint,
        onTap: () => tab(3),
      ),
      ActionCard(
        icon: Icons.fitness_center_rounded,
        label: 'Drill',
        title: 'Practice weak spots',
        tint: AppTint.lilac,
        onTap: () =>
            context.push('/language/practice', extra: const <String>[]),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Quick practice',
          actionLabel: 'Your goals',
          onAction: () => context.push('/goals'),
        ),
        const SizedBox(height: AppSpace.md),
        LayoutBuilder(
          builder: (context, c) {
            const gap = AppSpace.md;
            final w = (c.maxWidth - gap) / 2;
            // Grow the tile with the user's text scale so a larger font never
            // overflows the fixed-height grid.
            final scale =
                MediaQuery.textScalerOf(context).scale(16) / 16;
            final h = 148 * scale.clamp(1.0, 1.6);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in tiles) SizedBox(width: w, height: h, child: t),
              ],
            );
          },
        ),
      ],
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

/// Home greeting block (design spec): the learner's language and level, the
/// day's headline question, and a one-tap way into the tutor — typed or
/// spoken. No app bar; the greeting itself is the header.
class _HeaderCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final flag = availableLanguages
        .firstWhere(
          (l) => l.code == languageCode,
          orElse: () => availableLanguages.first,
        )
        .flag;
    void openTutor() => ref.read(homeTabProvider.notifier).state = 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LanguageMenu(),
            const Spacer(),
            if (ref.watch(authStateProvider).value?.isAdmin ?? false) ...[
              CircleIconButton(
                icon: Icons.library_add_outlined,
                size: 42,
                tooltip: 'Content Studio',
                onTap: () => context.push('/content'),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            CircleIconButton(
              icon: Icons.settings_outlined,
              size: 42,
              tooltip: 'Settings',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: AppSpace.sm),
            // Flexible: a long language name must ellipsize, not overflow.
            Flexible(
              child: Text(
                languageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tones.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
            ),
          ],
        ),
        Text(
          'What shall we work on?',
          style: TextStyle(
            color: tones.ink,
            fontSize: 27,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xs,
          children: [
            const SoftChip(label: 'A1 · CEFR'),
            SoftChip(label: '$answered answers', muted: true),
            SoftChip(
              label: '${(accuracy * 100).round()}% correct',
              muted: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        // Ask-the-tutor bar: the design's search field + voice affordance,
        // both routing into the live tutor session.
        Row(
          children: [
            Expanded(
              child: Material(
                color: tones.card,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: openTutor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg + 2,
                      vertical: AppSpace.lg,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 21,
                          color: tones.inkSoft,
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(
                            'Ask your teacher anything…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tones.inkSoft,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            CircleIconButton(
              icon: Icons.graphic_eq_rounded,
              size: 56,
              filled: true,
              tooltip: 'Talk to your teacher',
              onTap: openTutor,
            ),
          ],
        ),
      ],
    );
  }
}

/// The star of the app: your personal teacher, opening with the exact
/// misconception it plans to repair.
class _TutorHeroCard extends ConsumerWidget {
  const _TutorHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final learner = ref.watch(languageLearnerProvider);
    final curriculum = ref.watch(curriculumProvider).value;
    final top = learner.misconceptions.all.firstOrNull;
    return SoftCard(
      tint: AppTint.ink,
      padding: const EdgeInsets.all(AppSpace.lg + 4),
      onTap: () => ref.read(homeTabProvider.notifier).state = 3,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tones.onTint(AppTint.ink).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school,
              color: tones.onTint(AppTint.ink),
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your AI teacher is ready',
                  style: TextStyle(
                    color: tones.onTint(AppTint.ink),
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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
                    color: tones.onTint(AppTint.ink).withValues(alpha: 0.78),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Icon(
            Icons.arrow_forward_rounded,
            color: tones.onTint(AppTint.ink),
            size: 20,
          ),
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
    final tones = AppTones.of(context);
    return Material(
      color: tones.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.xs,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tones.cardMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: tones.ink),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: tones.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: tones.inkSoft, fontSize: 13),
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

/// 1 · Teacher's Notebook — the notebook view of the Teacher Brain (Phase 17).
/// Observations are generated live from the learner's facts and persisted
/// across sessions; each is explainable — tap a note to see the evidence
/// behind it. The live misconception card sits below for tap-through detail.
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
    ObservationCategory.connection: Icons.hub,
    ObservationCategory.mentalModel: Icons.lightbulb,
    ObservationCategory.curiosity: Icons.auto_awesome,
    ObservationCategory.plan: Icons.arrow_forward,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherBrainProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brain = async.value;
    if (brain == null) {
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
              // Expanded (not Spacer) so a long working-level line yields to
              // the streak pill and ellipsizes instead of overflowing.
              Expanded(
                child: Text(
                  'Working level: around ${brain.facts.cefr}',
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (brain.identity.streakDays > 0) ...[
                const SizedBox(width: 8),
                _Pill(
                  label: '${brain.identity.streakDays}-day streak',
                  color: scheme.secondaryContainer,
                  textColor: scheme.onSecondaryContainer,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final o in brain.notebook.observations)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: o.evidence.isEmpty
                  ? null
                  : () => _showObservationEvidence(context, o),
              child: Padding(
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
                    if (o.evidence.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Explainable AI: shows the facts that justify a notebook observation.
void _showObservationEvidence(BuildContext context, TeacherObservation o) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.text, style: text.titleSmall),
              const SizedBox(height: 16),
              Text(
                'Based on',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final e in o.evidence)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.label, style: text.bodyMedium)),
                      Text(
                        e.value,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (e.delta != null) ...[
                        const SizedBox(width: 8),
                        _Pill(
                          label:
                              '${e.delta! >= 0 ? '+' : ''}'
                              '${(e.delta! * 100).round()}%',
                          color: e.delta! >= 0
                              ? scheme.secondaryContainer
                              : scheme.errorContainer,
                          textColor: e.delta! >= 0
                              ? scheme.onSecondaryContainer
                              : scheme.onErrorContainer,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
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
/// Surfaces the single unified recommendation list (Phase 32 recommendation
/// engine, already merged with Phase 33 reader recs + Phase 34 connection
/// bridges in `recommendationsProvider`). Purely derived and read-only — it
/// shows what the engines computed, holds no state, and never invents an item:
/// an empty list means the engines found nothing pressing.
class _TeacherRecommendationsCard extends ConsumerWidget {
  const _TeacherRecommendationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(recommendationsProvider);

    if (async.isLoading && !async.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final recs = async.value ?? const <Recommendation>[];
    if (recs.isEmpty) {
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nothing urgent right now — keep going.',
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    final top = recs.take(3).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const Divider(height: AppSpace.md),
            InkWell(
              onTap: () => _launchRecommendation(context, ref, top[i]),
              borderRadius: BorderRadius.circular(AppRadius.input),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.secondaryContainer,
                      child: Icon(
                        _recIcon(top[i].kind),
                        size: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(top[i].reason, style: text.bodyMedium)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Acts on a tapped recommendation by routing to the activity that already
/// exists for it — reusing the same session/tab primitives as `_launchBlock`,
/// never a router push (so the home stays testable without GoRouter). The
/// unified tutor (Phase 18) is the catch-all: it addresses weak concepts,
/// misconceptions, and connections from the brain when tapped. Exhaustive over
/// the enum: a new kind is a compile error, never a silent no-op.
void _launchRecommendation(
  BuildContext context,
  WidgetRef ref,
  Recommendation r,
) {
  switch (r.kind) {
    case RecommendationKind.speaking:
      ref.read(speakingProvider.notifier)
        ..reset()
        ..start(focusConceptIds: r.requiredConcepts);
      ref.read(homeTabProvider.notifier).state = 2;
    case RecommendationKind.conversation:
    case RecommendationKind.roleplay:
      ref.read(tutorSessionProvider.notifier).start(TutorMode.conversation);
      ref.read(homeTabProvider.notifier).state = 3;
    case RecommendationKind.reading:
    case RecommendationKind.story:
      ref.read(homeTabProvider.notifier).state = 1; // Library
    case RecommendationKind.review:
    case RecommendationKind.recoverWeakConcept:
    case RecommendationKind.mentalModel:
    case RecommendationKind.connection:
    case RecommendationKind.continueJourney:
    case RecommendationKind.milestone:
    case RecommendationKind.challenge:
    case RecommendationKind.curiosity:
    case RecommendationKind.confidence:
    case RecommendationKind.celebrate:
      // Hand off to the unified teacher, which reads the same brain and
      // decides the concrete strategy (Phase 18 teachingChoiceProvider).
      ref.read(homeTabProvider.notifier).state = 3;
  }
}

/// Presentation-only icon for each recommendation kind. Exhaustive over the
/// enum so a new kind is a compile error, never a silent default.
IconData _recIcon(RecommendationKind kind) => switch (kind) {
      RecommendationKind.continueJourney => Icons.route_outlined,
      RecommendationKind.recoverWeakConcept => Icons.healing_outlined,
      RecommendationKind.review => Icons.refresh,
      RecommendationKind.conversation => Icons.forum_outlined,
      RecommendationKind.roleplay => Icons.theater_comedy_outlined,
      RecommendationKind.reading => Icons.menu_book_outlined,
      RecommendationKind.story => Icons.auto_stories_outlined,
      RecommendationKind.mentalModel => Icons.hub_outlined,
      RecommendationKind.connection => Icons.share_outlined,
      RecommendationKind.speaking => Icons.record_voice_over_outlined,
      RecommendationKind.curiosity => Icons.lightbulb_outline,
      RecommendationKind.milestone => Icons.flag_outlined,
      RecommendationKind.challenge => Icons.trending_up,
      RecommendationKind.confidence => Icons.favorite_outline,
      RecommendationKind.celebrate => Icons.celebration_outlined,
    };

/// Surfaces the Phase 32 Journey Engine (`journeyReportsProvider`) — each
/// engaged domain's derived path with assessed health and progress. Read-only
/// and derived; no state, no fabrication (an empty list means no journey has
/// formed yet). Reuses the same async pattern as the recommendations card.
class _JourneysCard extends ConsumerWidget {
  const _JourneysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(journeyReportsProvider);

    if (async.isLoading && !async.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final reports = async.value ?? const <JourneyReport>[];
    if (reports.isEmpty) {
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.route_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No journeys yet — keep learning and paths will form.',
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    final top = reports.take(3).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const Divider(height: AppSpace.md),
            _journeyRow(context, top[i]),
          ],
        ],
      ),
    );
  }
}

Widget _journeyRow(BuildContext context, JourneyReport r) {
  final scheme = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  final pct = (r.journey.progress * 100).round();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(r.journey.name, style: text.titleSmall)),
          Text(
            _journeyHealthLabel(r.health),
            style: text.labelSmall?.copyWith(color: scheme.primary),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: LinearProgressIndicator(
          value: r.journey.progress.clamp(0.0, 1.0),
          minHeight: 6,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '$pct% · ${r.prediction.nextMilestone ?? 'in progress'}',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ],
  );
}

/// Presentation label for journey health. Exhaustive: a new health value is a
/// compile error, never a silent blank.
String _journeyHealthLabel(JourneyHealth h) => switch (h) {
      JourneyHealth.healthy => 'On track',
      JourneyHealth.recovering => 'Recovering',
      JourneyHealth.plateau => 'Plateau',
      JourneyHealth.stalled => 'Stalled',
      JourneyHealth.accelerating => 'Accelerating',
      JourneyHealth.completed => 'Complete',
    };

/// Surfaces the Phase 30 Roleplay Engine (`roleplaySelectionProvider`) — the
/// scene the teacher would run now, with its rationale. Read-only preview and
/// derived; no state, no fabrication (null → an honest "not yet" line). Starting
/// the scene is a separate, later increment (needs a roleplay session loop).
class _RoleplaySuggestionCard extends ConsumerWidget {
  const _RoleplaySuggestionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final scene = ref.watch(roleplaySelectionProvider);

    if (scene == null) {
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.theater_comedy_outlined,
                size: 18, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'A practice scene will appear once your teacher knows you a '
                'little.',
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.tertiaryContainer,
                child: Icon(Icons.theater_comedy,
                    size: 18, color: scheme.onTertiaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  scene.resumed ? '${scene.title} (resume)' : scene.title,
                  style: text.titleSmall,
                ),
              ),
              _Pill(
                label: _roleplayDifficultyLabel(scene.difficulty),
                color: scheme.tertiaryContainer,
                textColor: scheme.onTertiaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(scene.setting, style: text.bodyMedium),
          const SizedBox(height: 4),
          Text(
            scene.rationale,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                // Phase 35: start (or resume) the scene in the tutor.
                ref.read(tutorSessionProvider.notifier).startRoleplay();
                ref.read(homeTabProvider.notifier).state = 3;
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(scene.resumed ? 'Resume scene' : 'Start scene'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Presentation label for roleplay difficulty. Exhaustive over the enum.
String _roleplayDifficultyLabel(RoleplayDifficulty d) => switch (d) {
      RoleplayDifficulty.gentle => 'Gentle',
      RoleplayDifficulty.standard => 'Standard',
      RoleplayDifficulty.stretch => 'Stretch',
    };

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
