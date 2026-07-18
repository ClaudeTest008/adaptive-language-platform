import 'notebook.dart';

/// Persists the learner's notebook snapshots across sessions — the app's
/// long-term memory (Phase 17). A seam so the store can move from device
/// preferences to Firestore later without touching the engine or UI.
abstract class TeacherNotebookRepository {
  /// Snapshots oldest-first.
  Future<List<NotebookSnapshot>> loadHistory();

  /// Records [snapshot], replacing any existing entry for the same day so a
  /// session that rebuilds many times keeps exactly one snapshot per day.
  Future<void> saveSnapshot(NotebookSnapshot snapshot);
}

/// Keeps at most this many days of history — plenty for trend notes, bounded
/// so the store never grows without limit.
const int notebookHistoryCap = 60;

/// Merges [snapshot] into [history]: one entry per day, oldest-first, capped.
/// Pure so both the in-memory and disk repositories share the same rule.
List<NotebookSnapshot> mergeSnapshot(
  List<NotebookSnapshot> history,
  NotebookSnapshot snapshot,
) {
  final next = [
    for (final s in history)
      if (s.day != snapshot.day) s,
    snapshot,
  ]..sort((a, b) => a.day.compareTo(b.day));
  if (next.length > notebookHistoryCap) {
    return next.sublist(next.length - notebookHistoryCap);
  }
  return next;
}

/// Test/default fallback store.
class InMemoryTeacherNotebookRepository implements TeacherNotebookRepository {
  final List<NotebookSnapshot> _history = [];

  @override
  Future<List<NotebookSnapshot>> loadHistory() async =>
      List.unmodifiable(_history);

  @override
  Future<void> saveSnapshot(NotebookSnapshot snapshot) async {
    final merged = mergeSnapshot(_history, snapshot);
    _history
      ..clear()
      ..addAll(merged);
  }
}
