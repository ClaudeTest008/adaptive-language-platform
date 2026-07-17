import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/story.dart';
import '../language_providers.dart';
import '../reading_state.dart';
import '../ui.dart';

/// Reading Library (Phase 14): a real book library — shelves of cover cards
/// (Continue Reading, Spanish Classics, Beginner, Intermediate) rather than
/// a flat story list. Each cover shows title, author, level, reading time,
/// chapter count and in-session progress. Reading feeds the same knowledge
/// graph as before; only the presentation changed.
class LanguageStoriesScreen extends ConsumerWidget {
  const LanguageStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Reading Library'),
      ),
      body: AtmosphericBackground(
        child: storiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load books:\n$e')),
          data: (stories) => ValueListenableBuilder<int>(
            valueListenable: readingRevision,
            builder: (context, _, _) {
            if (stories.isEmpty) {
              return const Center(child: Text('No books for your level yet.'));
            }
            bool started(Story s) {
              final last = readingLastPage[s.id];
              return last != null && last > 0;
            }

            final continueReading = [
              for (final s in stories)
                if (started(s) && !_finished(s)) s,
            ];
            final bookmarked = [
              for (final s in stories) if (isBookmarked(s.id)) s,
            ];
            final classics = [for (final s in stories) if (s.author.isNotEmpty) s];
            final beginner = [
              for (final s in stories) if (s.level == CefrLevel.a1) s,
            ];
            final intermediate = [
              for (final s in stories)
                if (s.level == CefrLevel.a2 || s.level == CefrLevel.b1) s,
            ];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    AppSpace.sm,
                    0,
                    AppSpace.xxl,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        0,
                        AppSpace.lg,
                        AppSpace.sm,
                      ),
                      child: Text(
                        'Classic Spanish literature and graded readers, '
                        'matched to your level.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    if (continueReading.isNotEmpty)
                      _Shelf(
                        title: 'Continue reading',
                        books: continueReading,
                        showProgress: true,
                      ),
                    if (bookmarked.isNotEmpty)
                      _Shelf(title: 'Bookmarks', books: bookmarked),
                    _Shelf(title: 'Spanish classics', books: classics),
                    _Shelf(title: 'Beginner · A1', books: beginner),
                    _Shelf(title: 'Intermediate · A2–B1', books: intermediate),
                  ],
                ),
              ),
            );
            },
          ),
        ),
      ),
    );
  }

  static bool _finished(Story s) {
    final last = readingLastPage[s.id];
    return last != null && last >= s.phrases.length - 1;
  }
}

/// A horizontally-scrolling shelf of book covers.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.books,
    this.showProgress = false,
  });

  final String title;
  final List<Story> books;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            AppSpace.sm,
          ),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 262,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
            itemBuilder: (context, i) => FadeInUp(
              delayMs: i * 45,
              child: _BookCover(story: books[i], showProgress: showProgress),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single book: a gradient placeholder cover with the title and level,
/// then author, reading time / chapters and (optionally) a progress bar.
class _BookCover extends StatelessWidget {
  const _BookCover({required this.story, this.showProgress = false});

  final Story story;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final last = readingLastPage[story.id];
    final progress =
        last == null ? 0.0 : ((last + 1) / story.phrases.length).clamp(0.0, 1.0);
    return SizedBox(
      width: 152,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.input),
        onTap: () => context.push('/story/${Uri.encodeComponent(story.id)}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover art (placeholder gradient) with title + level badge.
            Container(
              height: 168,
              width: 152,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      story.level.name.toUpperCase(),
                      style: text.labelSmall?.copyWith(color: scheme.onPrimary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    story.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              story.author.isEmpty ? 'Graded reader' : story.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${story.readingMinutes} min · ${story.phrases.length} ch',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (showProgress || progress > 0) ...[
              const SizedBox(height: AppSpace.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
