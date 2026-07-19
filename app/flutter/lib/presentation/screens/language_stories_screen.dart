import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../language/entities.dart';
import '../../language/reader_intelligence.dart';
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
    final tones = AppTones.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Reading Library'),
        actions: [
          // Phase 22: import your own text as a book (TXT paste today;
          // PDF/EPUB parsers arrive behind the same seam).
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.md),
            child: CircleIconButton(
              icon: Icons.upload_file_outlined,
              tooltip: 'Import text',
              size: 42,
              onTap: () => _showImportDialog(context, ref),
            ),
          ),
        ],
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
                        style: TextStyle(
                          color: tones.inkSoft,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    // Phase 35: the Reader Intelligence profile (Phase 33)
                    // made visible where reading lives. Renders nothing until
                    // a book has actually been finished — never fabricated.
                    const _ReaderProfileCard(),
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

/// Surfaces the Phase 33 Reader Intelligence profile (`readerProfileProvider`)
/// where reading lives. Read-only and derived: books read, confidence,
/// difficulty fit, and the first insight. Hidden entirely while the profile is
/// empty (no finished books) — an absent card is honest; a fabricated one is
/// not.
class _ReaderProfileCard extends ConsumerWidget {
  const _ReaderProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = AppTones.of(context);
    final profile = ref.watch(readerProfileProvider).value;
    if (profile == null || profile.isEmpty) return const SizedBox.shrink();

    final confidence = profile.readingConfidence;
    final fit = _fitLabel(profile.difficultyFit);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.md,
      ),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 18,
                  color: tones.solid(AppTint.mint),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Your reading',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tones.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (fit.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.sm),
                  Flexible(child: SoftChip(label: fit)),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              '${profile.booksRead} '
              '${profile.booksRead == 1 ? 'book' : 'books'} finished'
              '${confidence == null ? '' : ' · comprehension ${(confidence * 100).round()}%'}',
              style: TextStyle(color: tones.ink, fontSize: 14.5, height: 1.4),
            ),
            if (profile.insights.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                profile.insights.first,
                style: TextStyle(
                  color: tones.inkSoft,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Presentation label for reading difficulty fit. Exhaustive over the enum.
String _fitLabel(ReadingDifficultyFit fit) => switch (fit) {
      ReadingDifficultyFit.tooEasy => 'Ready for harder',
      ReadingDifficultyFit.ideal => 'Right level',
      ReadingDifficultyFit.tooHard => 'Take it gentle',
      ReadingDifficultyFit.unknown => '',
    };

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
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: SectionHeader(title: title),
        ),
        SizedBox(
          height: 268,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
            itemBuilder: (context, i) => FadeInUp(
              delayMs: i * 45,
              child: _BookCover(
                story: books[i],
                showProgress: showProgress,
                tint: _coverTints[i % _coverTints.length],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The cover placeholder palette — cycled by shelf position so a shelf reads
/// as a row of distinct books.
const _coverTints = [AppTint.sage, AppTint.sun, AppTint.mint, AppTint.lilac];

/// A single book: a tinted placeholder cover with the title and level,
/// then author, reading time / chapters and (optionally) a progress bar.
class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.story,
    this.showProgress = false,
    this.tint = AppTint.sage,
  });

  final Story story;
  final bool showProgress;
  final AppTint tint;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final last = readingLastPage[story.id];
    final progress =
        last == null ? 0.0 : ((last + 1) / story.phrases.length).clamp(0.0, 1.0);
    final fill = tones.tint(tint);
    final onFill = tones.onTint(tint);
    final deep = Color.alphaBlend(
      tones.solid(tint).withValues(alpha: tones.dark ? 0.32 : 0.42),
      fill,
    );
    return SizedBox(
      width: 152,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: () => context.push('/story/${Uri.encodeComponent(story.id)}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover art (tinted placeholder) with title + level badge.
            Container(
              height: 172,
              width: 152,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                gradient: LinearGradient(
                  colors: [fill, deep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: tones.dark
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SoftChip(label: story.level.name.toUpperCase()),
                  const Spacer(),
                  Text(
                    story.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onFill,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.2,
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
              style: TextStyle(
                color: tones.inkSoft,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              story.hasChapters
                  ? '${story.readingMinutes} min · '
                      '${story.chapterTitles.length} chapters'
                  : '${story.readingMinutes} min · '
                      '${story.phrases.length} pages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tones.inkSoft, fontSize: 11.5),
            ),
            if (showProgress || progress > 0) ...[
              const SizedBox(height: AppSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  color: tones.solid(tint),
                  backgroundColor: tones.cardMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Paste-a-text import (Phase 22). Kept dependency-free: the learner pastes
/// any passage or chapter; it becomes a readable, narrated, mineable book.
void _showImportDialog(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  final textCtrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTones.of(ctx).card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(
        'Import a text',
        style: TextStyle(
          color: AppTones.of(ctx).ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                labelText: 'Paste the text',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(readingExperienceProvider.notifier)
                .importText(title: titleCtrl.text, text: textCtrl.text);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: const Text('Import'),
        ),
      ],
    ),
  );
}
