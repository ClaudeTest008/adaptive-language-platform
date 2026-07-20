import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/ingestion.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Content Studio (ADR-0025): paste target-language text, preview the
/// extracted review candidates (vocabulary, phrases, sentences, idioms,
/// cultural notes) mapped to curriculum concepts, and approve/reject.
/// Admin-only — the human review queue for new language material.
class LanguageContentScreen extends ConsumerStatefulWidget {
  const LanguageContentScreen({super.key});

  @override
  ConsumerState<LanguageContentScreen> createState() =>
      _LanguageContentScreenState();
}

class _LanguageContentScreenState
    extends ConsumerState<LanguageContentScreen> {
  final _input = TextEditingController();

  static const _sample =
      'María tiene mucha hambre. Va a un pequeño restaurante en Sevilla. '
      'El camarero habla español despacio. María quiere comer una manzana '
      'roja. También tiene sed y tiene prisa. En España la comida es a las '
      'tres de la tarde. Ahora María está contenta.';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the curriculum warm so ingest() has the graph ready.
    ref.watch(curriculumProvider);
    final studio = ref.watch(contentStudioProvider);
    final result = studio.result;

    final tones = AppTones.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Content Studio'),
        actions: [
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.md),
              child: CircleIconButton(
                icon: Icons.clear_all,
                size: 42,
                tooltip: 'Clear',
                onTap: () {
                  _input.clear();
                  ref.read(contentStudioProvider.notifier).clear();
                },
              ),
            ),
        ],
      ),
      body: AtmosphericBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Text(
                  'Paste a passage in the target language. We extract '
                  'vocabulary, phrases, sentences, idioms and cultural notes '
                  'for you to review.',
                  style: TextStyle(
                    color: tones.inkSoft,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                TextField(
                  controller: _input,
                  minLines: 4,
                  maxLines: 8,
                  style: TextStyle(color: tones.ink, fontSize: 15),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: tones.card,
                    hintText: 'Paste text here…',
                    hintStyle: TextStyle(color: tones.inkSoft),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Extract',
                        icon: Icons.auto_awesome,
                        onPressed: () => ref
                            .read(contentStudioProvider.notifier)
                            .ingest(_input.text),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    SizedBox(
                      height: 58,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tones.ink,
                          side: BorderSide(color: tones.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () {
                          _input.text = _sample;
                          ref
                              .read(contentStudioProvider.notifier)
                              .ingest(_sample);
                        },
                        child: const Text(
                          'Use sample',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                if (result != null) ...[
                  const SizedBox(height: AppSpace.lg),
                  _Summary(result: result),
                  const SizedBox(height: AppSpace.sm),
                  for (final kind in ContentKind.values)
                    _KindSection(
                      kind: kind,
                      items: result.ofKind(kind),
                      review: studio.review,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final IngestionResult result;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return SoftCard(
      tint: AppTint.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.candidates.length} candidates · '
            '${result.difficulty.name.toUpperCase()} · '
            '${result.candidates.where((c) => c.mapped).length} mapped to curriculum',
            style: TextStyle(
              color: tones.onTint(AppTint.sage),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (result.topics.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm - 2,
              runSpacing: AppSpace.sm - 2,
              children: [for (final t in result.topics) SoftChip(label: t)],
            ),
          ],
        ],
      ),
    );
  }
}

class _KindSection extends ConsumerWidget {
  const _KindSection({
    required this.kind,
    required this.items,
    required this.review,
  });

  final ContentKind kind;
  final List<ContentCandidate> items;
  final ContentReviewLog review;

  static const _titles = {
    ContentKind.vocabulary: ('Vocabulary', Icons.style),
    ContentKind.phrase: ('Phrases', Icons.short_text),
    ContentKind.sentence: ('Example sentences', Icons.notes),
    ContentKind.idiom: ('Idioms', Icons.emoji_objects),
    ContentKind.culturalNote: ('Cultural notes', Icons.public),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (title, icon) = _titles[kind]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Icon(icon, size: 18, color: tones.solid(AppTint.lilac)),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                '$title (${items.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tones.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs - 1),
            child: SoftCard(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.text,
                          style: TextStyle(
                            color: tones.ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (c.translation != null)
                          Text(
                            c.translation!,
                            style: TextStyle(
                              color: tones.inkSoft,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: AppSpace.xs),
                        _StatusChip(candidate: c, review: review),
                      ],
                    ),
                  ),
                  if (review.isPending(c.id)) ...[
                    IconButton(
                      icon: Icon(
                        Icons.check_circle,
                        color: tones.solid(AppTint.mint),
                      ),
                      tooltip: 'Approve',
                      onPressed: () => ref
                          .read(contentStudioProvider.notifier)
                          .approve(c.id),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined, color: scheme.error),
                      tooltip: 'Reject',
                      onPressed: () => ref
                          .read(contentStudioProvider.notifier)
                          .reject(c.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.candidate, required this.review});

  final ContentCandidate candidate;
  final ContentReviewLog review;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = review.approved.contains(candidate.id)
        ? ('Approved', tones.solid(AppTint.mint))
        : review.rejected.contains(candidate.id)
        ? ('Rejected', scheme.error)
        : candidate.mapped
        ? (
            'Maps to ${candidate.conceptId!.split(':').last}',
            tones.solid(AppTint.lilac),
          )
        : ('New — ${candidate.note ?? "review"}', tones.inkSoft);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );
  }
}
