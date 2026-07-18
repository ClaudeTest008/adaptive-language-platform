import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../language/notebook.dart';
import '../language/notebook_repository.dart';

/// Disk-backed notebook store using shared_preferences — the first real
/// cross-session persistence in the app (Phase 17). Offline-first: no network,
/// no account required. History is a single JSON string under one key.
class PrefsTeacherNotebookRepository implements TeacherNotebookRepository {
  static const _key = 'teacher_notebook_history_v1';

  @override
  Future<List<NotebookSnapshot>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(NotebookSnapshot.fromJson).toList()
        ..sort((a, b) => a.day.compareTo(b.day));
    } catch (_) {
      // Corrupt/legacy payload — start fresh rather than crash the home.
      return const [];
    }
  }

  @override
  Future<void> saveSnapshot(NotebookSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = mergeSnapshot(await loadHistory(), snapshot);
    await prefs.setString(
      _key,
      jsonEncode([for (final s in merged) s.toJson()]),
    );
  }
}
