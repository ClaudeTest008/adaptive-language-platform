import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/exam_logic.dart';
import '../../domain/models.dart';
import '../providers.dart';
import '../widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final stats = ref.watch(topicStatsProvider);
    final attempts = ref.watch(attemptsProvider);
    final topics = ref.watch(topicsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.displayName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search questions',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsRow(stats: stats, attempts: attempts),
            const SizedBox(height: 16),
            const _ReadinessCard(),
            const SizedBox(height: 16),
            _WeakTopics(stats: stats, topics: topics),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.language,
              title: 'Language Lab',
              subtitle: 'Spanish demo — skill mastery, teacher notes, lessons',
              onTap: () => context.push('/language'),
            ),
            _ActionCard(
              icon: Icons.menu_book,
              title: 'Practice',
              subtitle: 'Immediate feedback and explanations',
              onTap: () => context.push('/practice'),
            ),
            _ActionCard(
              icon: Icons.timer,
              title: 'Mock Exam',
              subtitle: 'Timed, randomized, pass/fail',
              onTap: () => context.push('/exam'),
            ),
            _ActionCard(
              icon: Icons.bookmark,
              title: 'Bookmarks',
              subtitle: 'Questions you saved',
              onTap: () => context.push('/bookmarks'),
            ),
            if (user?.isAdmin ?? false)
              _ActionCard(
                icon: Icons.admin_panel_settings,
                title: 'Content Studio',
                subtitle: 'Manage exams, questions, bulk import',
                onTap: () => context.push('/admin'),
              ),
            const SizedBox(height: 16),
            _RecentAttempts(attempts: attempts),
          ],
        ),
      ),
    );
  }
}

/// Adaptive engine summary: readiness, pass probability, today's plan.
class _ReadinessCard extends ConsumerWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(readinessProvider).value;
    final plan = ref.watch(studyPlanProvider).value;
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    if (readiness == null || plan == null) return const SizedBox.shrink();

    String pct(double v) => '${(v * 100).round()}%';
    String topicName(String id) =>
        topics.where((t) => t.id == id).firstOrNull?.name ?? id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Exam readiness',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: readiness.readiness, minHeight: 8),
            const SizedBox(height: 8),
            Text(
              '${pct(readiness.readiness)} ready · '
              '${pct(readiness.passProbability)} pass probability · '
              '${pct(readiness.knowledgeCoverage)} coverage',
            ),
            if (plan.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Today's plan (~${plan.estimatedMinutes} min"
                '${plan.dueReviewCount > 0 ? ", ${plan.dueReviewCount} reviews due" : ""})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final item in plan.items.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• ${topicName(item.conceptId)} — ${item.reason} '
                    '(${item.suggestedQuestions} questions)',
                  ),
                ),
              if (plan.recommendMockExam)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('• You look ready — take a mock exam'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.attempts});

  final AsyncValue<Map<String, TopicStats>> stats;
  final AsyncValue<List<Attempt>> attempts;

  @override
  Widget build(BuildContext context) {
    final topicStats = stats.value?.values ?? const <TopicStats>[];
    final answered = topicStats.fold(0, (sum, s) => sum + s.answered);
    final correct = topicStats.fold(0, (sum, s) => sum + s.correct);
    final accuracy = answered == 0
        ? '—'
        : '${(correct / answered * 100).round()}%';
    final mocks = (attempts.value ?? const <Attempt>[])
        .where((a) => a.type == AttemptType.mock)
        .toList();
    final passed = mocks.where((a) => a.passed == true).length;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Answered',
            value: '$answered',
            icon: Icons.quiz,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: 'Accuracy',
            value: accuracy,
            icon: Icons.track_changes,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: 'Exams passed',
            value: '$passed/${mocks.length}',
            icon: Icons.emoji_events,
          ),
        ),
      ],
    );
  }
}

class _WeakTopics extends StatelessWidget {
  const _WeakTopics({required this.stats, required this.topics});

  final AsyncValue<Map<String, TopicStats>> stats;
  final AsyncValue<List<Topic>> topics;

  @override
  Widget build(BuildContext context) {
    final statsMap = stats.value;
    final topicList = topics.value;
    if (statsMap == null || topicList == null) return const SizedBox.shrink();
    final weak = weakTopics(statsMap.values);
    if (weak.isEmpty) return const SizedBox.shrink();

    String nameOf(String id) => topicList
        .firstWhere(
          (t) => t.id == id,
          orElse: () => Topic(id: id, name: id, order: 0),
        )
        .name;

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weak topics — focus here',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final s in weak)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${nameOf(s.topicId)} — ${(s.accuracy * 100).round()}% '
                  '(${s.correct}/${s.answered})',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RecentAttempts extends StatelessWidget {
  const _RecentAttempts({required this.attempts});

  final AsyncValue<List<Attempt>> attempts;

  @override
  Widget build(BuildContext context) {
    final list = attempts.value ?? const <Attempt>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Study history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final a in list.take(8))
          Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: ListTile(
              dense: true,
              leading: Icon(
                a.type == AttemptType.mock ? Icons.timer : Icons.menu_book,
              ),
              title: Text(
                a.type == AttemptType.mock
                    ? 'Mock exam — ${a.passed == true ? "PASSED" : "FAILED"}'
                    : 'Practice session',
              ),
              subtitle: Text('${a.score}/${a.total} · ${_fmt(a.completedAt)}'),
            ),
          ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
