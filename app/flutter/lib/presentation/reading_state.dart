/// Session-only reading continuity (Phase 14): the last page read per book
/// and in-session bookmarks. Deliberately NOT a Riverpod provider or a
/// repository — just plain in-memory state so the reader resumes and the
/// library can show a "Continue Reading" shelf within a run. Resets on app
/// restart; real persistence lands with the Firestore swap.
library;

import 'package:flutter/foundation.dart';

/// storyId → last page index the learner reached.
final Map<String, int> readingLastPage = {};

/// storyId → bookmarked this session.
final Set<String> readingBookmarks = {};

/// Bumped whenever reading state changes, so views (e.g. the Library's
/// "Continue reading" shelf) can rebuild via a ValueListenableBuilder —
/// no Riverpod provider needed for this session-only UX state.
final ValueNotifier<int> readingRevision = ValueNotifier<int>(0);

void saveReadingPage(String storyId, int page) {
  if (readingLastPage[storyId] == page) return;
  readingLastPage[storyId] = page;
  readingRevision.value++;
}

int lastReadingPage(String storyId) => readingLastPage[storyId] ?? 0;

bool isBookmarked(String storyId) => readingBookmarks.contains(storyId);

void toggleBookmark(String storyId) {
  if (!readingBookmarks.remove(storyId)) readingBookmarks.add(storyId);
  readingRevision.value++;
}
