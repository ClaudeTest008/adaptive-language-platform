import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../language/teacher_memory.dart';

/// Disk-backed Teacher Memory (Phase 31), mirroring the notebook/experience
/// prefs repositories: completed lessons + the last roleplay position as JSON.
/// Offline, local; the teacher truly remembers across restarts.
class PrefsTeacherMemoryRepository implements TeacherMemoryRepository {
  static const _lessonsKey = 'teacher_memory_lessons_v1';
  static const _roleplayKey = 'teacher_memory_roleplay_v1';

  @override
  Future<List<CompletedLesson>> loadLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lessonsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final e in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          CompletedLesson.fromJson(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> appendLesson(CompletedLesson lesson) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = mergeLesson(await loadLessons(), lesson);
    await prefs.setString(
      _lessonsKey,
      jsonEncode([for (final l in merged) l.toJson()]),
    );
  }

  @override
  Future<RoleplayMemory?> loadRoleplay() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_roleplayKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RoleplayMemory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRoleplay(RoleplayMemory? roleplay) async {
    final prefs = await SharedPreferences.getInstance();
    if (roleplay == null) {
      await prefs.remove(_roleplayKey);
    } else {
      await prefs.setString(_roleplayKey, jsonEncode(roleplay.toJson()));
    }
  }
}
