import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/import_pipeline.dart';
import '../../application/large_import.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../providers.dart';

/// Content Studio V1 slice (ADR-0007): overview + exam settings, question
/// management, bulk import pipeline, content-pack export/import.
class AdminStudioScreen extends StatelessWidget {
  const AdminStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Content Studio'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.quiz), text: 'Questions'),
              Tab(icon: Icon(Icons.upload_file), text: 'Import'),
              Tab(icon: Icon(Icons.fact_check), text: 'Review'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _QuestionsTab(),
            _ImportTab(),
            _ReviewTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- overview

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = ref.watch(examProvider).value;
    final all = ref.watch(allQuestionsProvider).value ?? const <Question>[];
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    int byStatus(ContentStatus s) => all.where((q) => q.status == s).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ContentStatus.values)
              _CountChip(s.name, byStatus(s)),
            _CountChip('Topics', topics.length),
          ],
        ),
        const Divider(height: 32),
        Text(
          'Topic coverage (published)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final t in topics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${t.name}: '
              '${all.where((q) => q.topicId == t.id && q.status == ContentStatus.published).length} questions',
            ),
          ),
        Builder(
          builder: (context) {
            final authors = <String, int>{};
            for (final q in all) {
              if (q.author != null) {
                authors[q.author!] = (authors[q.author!] ?? 0) + 1;
              }
            }
            if (authors.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Authors: ${authors.entries.map((e) => "${e.key} (${e.value})").join(", ")}',
              ),
            );
          },
        ),
        const Divider(height: 32),
        Text('Exam settings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (exam != null) _ExamForm(exam: exam),
        const Divider(height: 32),
        Text('Content pack', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export pack (copy JSON)'),
              onPressed: () async {
                final json = await ref
                    .read(adminRepositoryProvider)
                    .exportContentPack();
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Content pack copied to clipboard.'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Import pack'),
              onPressed: () => _importPackDialog(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importPackDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import content pack'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste content-pack JSON…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty) return;
    try {
      final count = await ref
          .read(adminRepositoryProvider)
          .importContentPack(json);
      ref.read(contentVersionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported pack: $count questions.')),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pack import failed: $e')));
      }
    }
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $count'));
}

class _ExamForm extends ConsumerStatefulWidget {
  const _ExamForm({required this.exam});

  final Exam exam;

  @override
  ConsumerState<_ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends ConsumerState<_ExamForm> {
  late final _name = TextEditingController(text: widget.exam.name);
  late final _count = TextEditingController(
    text: '${widget.exam.questionCount}',
  );
  late final _pass = TextEditingController(
    text: '${widget.exam.passThreshold}',
  );
  late final _time = TextEditingController(
    text: '${widget.exam.timeLimitMinutes}',
  );

  @override
  void dispose() {
    for (final c in [_name, _count, _pass, _time]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
    return Column(
      children: [
        TextField(controller: _name, decoration: deco('Exam name')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _count,
                decoration: deco('Questions per exam'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pass,
                decoration: deco('Pass threshold'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _time,
                decoration: deco('Time limit (min)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              final count = int.tryParse(_count.text);
              final pass = int.tryParse(_pass.text);
              final time = int.tryParse(_time.text);
              if (_name.text.trim().isEmpty ||
                  count == null ||
                  count <= 0 ||
                  pass == null ||
                  pass <= 0 ||
                  pass > count ||
                  time == null ||
                  time <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invalid exam settings: positive numbers required, '
                      'pass threshold must not exceed question count.',
                    ),
                  ),
                );
                return;
              }
              await ref
                  .read(adminRepositoryProvider)
                  .updateExam(
                    widget.exam.copyWith(
                      name: _name.text.trim(),
                      questionCount: count,
                      passThreshold: pass,
                      timeLimitMinutes: time,
                    ),
                  );
              ref.read(contentVersionProvider.notifier).state++;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exam settings saved.')),
                );
              }
            },
            child: const Text('Save exam'),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- questions

class _QuestionsTab extends ConsumerStatefulWidget {
  const _QuestionsTab();

  @override
  ConsumerState<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends ConsumerState<_QuestionsTab> {
  String _query = '';
  ContentStatus? _statusFilter;
  String? _topicFilter;
  Difficulty? _difficultyFilter;
  final _selected = <String>{};

  Future<void> _bulk(
    Future<void> Function(AdminRepository repo, List<String> ids) action,
    String doneMessage,
  ) async {
    final ids = _selected.toList();
    await action(ref.read(adminRepositoryProvider), ids);
    ref.read(contentVersionProvider.notifier).state++;
    setState(_selected.clear);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$doneMessage (${ids.length} questions).')),
      );
    }
  }

  Future<void> _bulkTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tag to selected questions'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tag',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add tag'),
          ),
        ],
      ),
    );
    if (tag == null || tag.isEmpty) return;
    await _bulk((repo, ids) => repo.bulkAddTag(ids, tag), 'Tagged "$tag"');
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allQuestionsProvider).value ?? const <Question>[];
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    final q = _query.trim().toLowerCase();
    final filtered = all.where((question) {
      if (_statusFilter != null && question.status != _statusFilter) {
        return false;
      }
      if (_topicFilter != null && question.topicId != _topicFilter) {
        return false;
      }
      if (_difficultyFilter != null &&
          question.difficulty != _difficultyFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return question.text.toLowerCase().contains(q) ||
          question.explanation.toLowerCase().contains(q) ||
          question.tags.any((t) => t.toLowerCase().contains(q));
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    String topicName(String id) =>
        topics.where((t) => t.id == id).firstOrNull?.name ?? id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search text, explanation, tags…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<ContentStatus?>(
                value: _statusFilter,
                hint: const Text('Status'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final s in ContentStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _topicFilter,
                hint: const Text('Topic'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final t in topics)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) => setState(() => _topicFilter = v),
              ),
              const SizedBox(width: 8),
              DropdownButton<Difficulty?>(
                value: _difficultyFilter,
                hint: const Text('Difficulty'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final d in Difficulty.values)
                    DropdownMenuItem(value: d, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _difficultyFilter = v),
              ),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('${_selected.length} selected'),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _bulk(
                    (repo, ids) =>
                        repo.bulkSetStatus(ids, ContentStatus.published),
                    'Published',
                  ),
                  child: const Text('Publish'),
                ),
                TextButton(
                  onPressed: () => _bulk(
                    (repo, ids) =>
                        repo.bulkSetStatus(ids, ContentStatus.archived),
                    'Archived',
                  ),
                  child: const Text('Archive'),
                ),
                TextButton(
                  onPressed: () => _bulk(
                    (repo, ids) => repo.bulkSetStatus(ids, ContentStatus.draft),
                    'Restored to draft',
                  ),
                  child: const Text('Restore'),
                ),
                TextButton(onPressed: _bulkTag, child: const Text('Tag…')),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final question = filtered[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Checkbox(
                    value: _selected.contains(question.id),
                    onChanged: (v) => setState(() {
                      v == true
                          ? _selected.add(question.id)
                          : _selected.remove(question.id);
                    }),
                  ),
                  title: Text(
                    question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${topicName(question.topicId)} · '
                    '${question.difficulty.name} · '
                    '${question.status.name} · v${question.version}'
                    '${question.tags.isEmpty ? "" : " · ${question.tags.join(", ")}"}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (question.version > 1)
                        IconButton(
                          icon: const Icon(Icons.history),
                          tooltip: 'Version history',
                          onPressed: () =>
                              _showVersionHistory(context, ref, question),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                        onPressed: () =>
                            showQuestionEditor(context, ref, question),
                      ),
                      if (question.status != ContentStatus.archived)
                        IconButton(
                          icon: const Icon(Icons.archive_outlined),
                          tooltip: 'Archive',
                          onPressed: () async {
                            await ref
                                .read(adminRepositoryProvider)
                                .archiveQuestion(question.id);
                            ref.read(contentVersionProvider.notifier).state++;
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New question'),
            onPressed: () => showQuestionEditor(context, ref, null),
          ),
        ),
      ],
    );
  }
}

Future<void> _showVersionHistory(
  BuildContext context,
  WidgetRef ref,
  Question question,
) async {
  final history = await ref
      .read(adminRepositoryProvider)
      .getVersionHistory(question.id);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Version history — v${question.version} current'),
      content: SizedBox(
        width: 520,
        child: history.isEmpty
            ? const Text('No previous versions.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: history.length,
                itemBuilder: (context, i) {
                  final v = history[i];
                  String? changed(String label, String old, String current) =>
                      old == current ? null : '$label: "$old" → "$current"';
                  final diffs = [
                    changed('Text', v.text, question.text),
                    changed('Explanation', v.explanation, question.explanation),
                    changed(
                      'Correct',
                      v.answers[v.correctIndex],
                      question.answers[question.correctIndex],
                    ),
                    changed('Status', v.status.name, question.status.name),
                    changed('Topic', v.topicId, question.topicId),
                    changed('Tags', v.tags.join(','), question.tags.join(',')),
                  ].whereType<String>().toList();
                  return ExpansionTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(
                        'v${v.version}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    title: Text(
                      v.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${v.status.name}'
                      '${v.author != null ? " · ${v.author}" : ""}'
                      '${v.updatedAt != null ? " · ${v.updatedAt!.toString().substring(0, 16)}" : ""}',
                    ),
                    trailing: TextButton(
                      child: const Text('Rollback'),
                      onPressed: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .rollbackQuestion(question.id, v.version);
                        ref.read(contentVersionProvider.notifier).state++;
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Rolled back to v${v.version} content '
                                '(as a new version).',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: diffs.isEmpty
                              ? [const Text('Identical to current version.')]
                              : [
                                  Text(
                                    'Differences vs current '
                                    'v${question.version}:',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  for (final d in diffs)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('• $d'),
                                    ),
                                ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Visual question editor (dialog). Non-technical: plain form fields.
Future<void> showQuestionEditor(
  BuildContext context,
  WidgetRef ref,
  Question? original,
) async {
  final topics = ref.read(topicsProvider).value ?? const <Topic>[];
  final exam = ref.read(examProvider).value;
  if (topics.isEmpty || exam == null) return;

  final text = TextEditingController(text: original?.text ?? '');
  final answers = [
    for (var i = 0; i < 4; i++)
      TextEditingController(
        text: (original?.answers.length ?? 0) > i ? original!.answers[i] : '',
      ),
  ];
  final explanation = TextEditingController(text: original?.explanation ?? '');
  final tags = TextEditingController(text: original?.tags.join(', ') ?? '');
  var topicId = original?.topicId ?? topics.first.id;
  var correct = original?.correctIndex ?? 0;
  var difficulty = original?.difficulty ?? Difficulty.medium;
  var status = original?.status ?? ContentStatus.draft;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          original == null
              ? 'New question'
              : 'Edit question (v${original.version})',
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          // ignore: deprecated_member_use
                          groupValue: correct,
                          // ignore: deprecated_member_use
                          onChanged: (v) => setState(() => correct = v!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: answers[i],
                            decoration: InputDecoration(
                              labelText:
                                  'Answer ${String.fromCharCode(65 + i)}'
                                  '${i < 2 ? "" : " (optional)"}',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: explanation,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: topicId,
                        decoration: const InputDecoration(
                          labelText: 'Topic',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final t in topics)
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                        ],
                        onChanged: (v) => setState(() => topicId = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<Difficulty>(
                        initialValue: difficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final d in Difficulty.values)
                            DropdownMenuItem(value: d, child: Text(d.name)),
                        ],
                        onChanged: (v) => setState(() => difficulty = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<ContentStatus>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final s in ContentStatus.values)
                            DropdownMenuItem(value: s, child: Text(s.name)),
                        ],
                        onChanged: (v) => setState(() => status = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tags,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final answerTexts = [
                for (final c in answers)
                  if (c.text.trim().isNotEmpty) c.text.trim(),
              ];
              if (text.text.trim().isEmpty ||
                  answerTexts.length < 2 ||
                  correct >= answerTexts.length ||
                  explanation.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Question, at least 2 answers, a correct answer among '
                      'them, and an explanation are required.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (saved == true) {
    final answerTexts = [
      for (final c in answers)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    final user = ref.read(authStateProvider).value;
    final question = Question(
      id:
          original?.id ??
          'adm-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}',
      examId: exam.id,
      topicId: topicId,
      text: text.text.trim(),
      answers: answerTexts,
      correctIndex: correct,
      explanation: explanation.text.trim(),
      difficulty: difficulty,
      status: status,
      version: original?.version ?? 1,
      tags: tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      subtopic: original?.subtopic,
      learningObjective: original?.learningObjective,
      references: original?.references ?? const [],
      author: user?.email,
    );
    await ref.read(adminRepositoryProvider).upsertQuestion(question);
    ref.read(contentVersionProvider.notifier).state++;
  }

  text.dispose();
  for (final c in answers) {
    c.dispose();
  }
  explanation.dispose();
  tags.dispose();
}

// ------------------------------------------------------------------ import

class _ImportTab extends ConsumerStatefulWidget {
  const _ImportTab();

  @override
  ConsumerState<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends ConsumerState<_ImportTab> {
  final _content = TextEditingController();
  ImportFormat _format = ImportFormat.csv;
  ImportReport? _report;
  bool _importing = false;
  LargeImportProgress? _largeProgress;

  /// Chunked path: candidates land in the review queue instead of the
  /// content library (large imports never bypass human review).
  Future<void> _runLargeImport() async {
    final exam = ref.read(examProvider).value;
    final topics = ref.read(topicsProvider).value ?? const <Topic>[];
    if (exam == null) return;
    final repo = ref.read(adminRepositoryProvider);
    final existing = await repo.getAllQuestions();
    setState(() => _importing = true);
    await for (final progress in runLargeImport(
      content: _content.text,
      format: _format,
      examId: exam.id,
      topics: topics,
      existing: existing,
      repo: repo,
      author: ref.read(authStateProvider).value?.email,
    )) {
      if (!mounted) return;
      setState(() => _largeProgress = progress);
    }
    ref.read(contentVersionProvider.notifier).state++;
    if (mounted) {
      final p = _largeProgress;
      setState(() {
        _importing = false;
        _report = null;
        _content.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${p?.saved ?? 0} candidates sent to the Review tab '
            '(${p?.rejected ?? 0} rejected, ${p?.duplicates ?? 0} duplicates).',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _runPipeline() async {
    final exam = ref.read(examProvider).value;
    final topics = ref.read(topicsProvider).value ?? const <Topic>[];
    final existing = await ref.read(adminRepositoryProvider).getAllQuestions();
    final user = ref.read(authStateProvider).value;
    if (exam == null) return;
    setState(() {
      _report = runImportPipeline(
        content: _content.text,
        format: _format,
        examId: exam.id,
        topics: topics,
        existing: existing,
        author: user?.email,
      );
    });
  }

  Future<void> _approveAndImport({required bool publish}) async {
    final report = _report;
    if (report == null || !report.canImport) return;
    setState(() => _importing = true);
    final stopwatch = Stopwatch()..start();
    final questions = publish
        ? [
            for (final q in report.questions)
              q.copyWith(status: ContentStatus.published),
          ]
        : report.questions;
    final repo = ref.read(adminRepositoryProvider);
    await repo.importQuestions(questions);
    stopwatch.stop();
    final rejectedRows = {
      for (final issue in report.errors)
        if (issue.row > 0) issue.row,
    }.length;
    await repo.recordImportJob(
      ImportJob(
        id: 'job-${report.hashCode.toRadixString(16)}-${questions.length}',
        startedAt: DateTime.now(),
        format: _format.name,
        rowsTotal: questions.length + rejectedRows,
        imported: questions.length,
        rejected: rejectedRows,
        duplicates: report.duplicateCount,
        durationMs: stopwatch.elapsedMilliseconds,
        author: ref.read(authStateProvider).value?.email,
      ),
    );
    ref.read(contentVersionProvider.notifier).state++;
    setState(() {
      _importing = false;
      _report = null;
      _content.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${questions.length} questions as '
            '${publish ? "published" : "drafts"}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            SegmentedButton<ImportFormat>(
              segments: const [
                ButtonSegment(value: ImportFormat.csv, label: Text('CSV')),
                ButtonSegment(value: ImportFormat.json, label: Text('JSON')),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy CSV template'),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: csvTemplate));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template copied.')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _content,
          maxLines: 10,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: _format == ImportFormat.csv
                ? 'Paste CSV (header row required)…'
                : 'Paste JSON array of question objects…',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.rule),
          label: const Text('Validate'),
          onPressed: _content.text.trim().isEmpty && _report == null
              ? _runPipeline // still allow: pipeline reports empty file
              : _runPipeline,
        ),
        if (report != null) ...[
          const Divider(height: 32),
          Text(
            'Validation report',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Valid: ${report.questions.length}')),
              Chip(
                label: Text('Errors: ${report.errors.length}'),
                backgroundColor: report.errors.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.errorContainer,
              ),
              Chip(label: Text('Warnings: ${report.warnings.length}')),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in report.issues.take(50))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                issue.toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: issue.blocking
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          if (report.issues.length > 50)
            Text('…and ${report.issues.length - 50} more.'),
          const SizedBox(height: 12),
          if (report.canImport) ...[
            Text(
              'Preview (${report.questions.length} questions ready)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final q in report.questions.take(5))
              Card(
                child: ListTile(
                  dense: true,
                  title: Text(q.text),
                  subtitle: Text(
                    '${q.answers.length} answers · correct: '
                    '${q.answers[q.correctIndex]} · ${q.difficulty.name}',
                  ),
                ),
              ),
            if (report.questions.length > 5)
              Text('…and ${report.questions.length - 5} more.'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Approve — import as published'),
                  onPressed: _importing
                      ? null
                      : () => _approveAndImport(publish: true),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _importing
                      ? null
                      : () => _approveAndImport(publish: false),
                  child: const Text('Import as drafts'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.rate_review),
                  onPressed: _importing ? null : _runLargeImport,
                  label: const Text('Send to review queue'),
                ),
              ],
            ),
            if (_largeProgress != null && !_largeProgress!.done) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _largeProgress!.fraction),
              Text(
                '${_largeProgress!.processed} / ${_largeProgress!.total} processed',
              ),
            ],
          ] else
            Text(
              report.questions.isEmpty
                  ? 'Nothing importable yet.'
                  : 'Resolve all blocking errors before importing.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        const _ImportJobHistory(),
      ],
    );
  }
}

// ------------------------------------------------------------------ review

/// Human review queue (ADR-0011): candidates from large imports, document
/// ingestion and AI generation. Approve creates an `approved` question
/// (publish is a separate, deliberate step); reject discards.
class _ReviewTab extends ConsumerWidget {
  const _ReviewTab();

  Future<void> _approve(
    WidgetRef ref,
    List<QuestionCandidate> candidates,
  ) async {
    final repo = ref.read(adminRepositoryProvider);
    for (final c in candidates) {
      await repo.upsertQuestion(
        c.question.copyWith(status: ContentStatus.approved),
      );
    }
    await repo.removeCandidates([for (final c in candidates) c.id]);
    ref.read(contentVersionProvider.notifier).state++;
  }

  Future<void> _reject(
    WidgetRef ref,
    List<QuestionCandidate> candidates,
  ) async {
    await ref.read(adminRepositoryProvider).removeCandidates([
      for (final c in candidates) c.id,
    ]);
    ref.read(contentVersionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates =
        ref.watch(candidatesProvider).value ?? const <QuestionCandidate>[];
    if (candidates.isEmpty) {
      return const Center(
        child: Text(
          'Review queue is empty.\n'
          'Large imports and AI-generated content land here first.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final sorted = List.of(candidates)
      ..sort((a, b) => a.quality.score.compareTo(b.quality.score));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${sorted.length} awaiting review '
                '(lowest quality first)',
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _approve(ref, sorted),
                child: Text('Approve all (${sorted.length})'),
              ),
              TextButton(
                onPressed: () => _reject(ref, sorted),
                child: const Text('Reject all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final c = sorted[i];
              final pct = (c.quality.score * 100).round();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: c.quality.score >= 0.7
                        ? Colors.green.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.errorContainer,
                    child: Text('$pct', style: const TextStyle(fontSize: 11)),
                  ),
                  title: Text(
                    c.question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${c.source.name} · ${c.question.difficulty.name}'
                    '${c.question.author != null ? " · ${c.question.author}" : ""}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var a = 0; a < c.question.answers.length; a++)
                            Text(
                              '${a == c.question.correctIndex ? "✓" : "•"} '
                              '${c.question.answers[a]}',
                              style: a == c.question.correctIndex
                                  ? const TextStyle(fontWeight: FontWeight.bold)
                                  : null,
                            ),
                          const SizedBox(height: 4),
                          Text('Explanation: ${c.question.explanation}'),
                          if (c.sourceExcerpt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Source: "${c.sourceExcerpt}"',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (c.quality.issues.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Quality issues:',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            for (final issue in c.quality.issues)
                              Text('• $issue'),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () => _approve(ref, [c]),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _reject(ref, [c]),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ImportJobHistory extends ConsumerWidget {
  const _ImportJobHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(importJobsProvider).value ?? const <ImportJob>[];
    if (jobs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text('Import history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final job in jobs.take(10))
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long),
              title: Text(
                '${job.format.toUpperCase()} — ${job.imported} imported, '
                '${job.rejected} rejected, ${job.duplicates} duplicates',
              ),
              subtitle: Text(
                '${job.startedAt.toString().substring(0, 16)} · '
                '${job.durationMs} ms'
                '${job.author != null ? " · ${job.author}" : ""}',
              ),
            ),
          ),
      ],
    );
  }
}
