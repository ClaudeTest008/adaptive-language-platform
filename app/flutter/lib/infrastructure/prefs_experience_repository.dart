import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../language/experience.dart';

/// Persists the Learning Experience evidence (Phase 22): finished-reading
/// records, imported books' raw text, and saved words. Offline, local, one
/// JSON blob per concern. A seam so Firestore can replace it later.
abstract class ExperienceRepository {
  Future<List<ReadingRecord>> loadReadingRecords();
  Future<void> addReadingRecord(ReadingRecord record);
  Future<Map<String, ({String title, String text})>> loadImportedBooks();
  Future<void> saveImportedBook(String id, String title, String text);
  Future<Set<String>> loadSavedWords();
  Future<void> saveWord(String word);
}

class InMemoryExperienceRepository implements ExperienceRepository {
  final List<ReadingRecord> _records = [];
  final Map<String, ({String title, String text})> _books = {};
  final Set<String> _words = {};

  @override
  Future<List<ReadingRecord>> loadReadingRecords() async =>
      List.unmodifiable(_records);

  @override
  Future<void> addReadingRecord(ReadingRecord record) async =>
      _records.add(record);

  @override
  Future<Map<String, ({String title, String text})>> loadImportedBooks()
      async => Map.unmodifiable(_books);

  @override
  Future<void> saveImportedBook(String id, String title, String text) async =>
      _books[id] = (title: title, text: text);

  @override
  Future<Set<String>> loadSavedWords() async => Set.unmodifiable(_words);

  @override
  Future<void> saveWord(String word) async => _words.add(word);
}

class PrefsExperienceRepository implements ExperienceRepository {
  static const _recordsKey = 'experience_reading_records_v1';
  static const _booksKey = 'experience_imported_books_v1';
  static const _wordsKey = 'experience_saved_words_v1';

  /// Bounded so the store never grows without limit.
  static const _recordCap = 200;

  @override
  Future<List<ReadingRecord>> loadReadingRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final e in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          ReadingRecord.fromJson(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> addReadingRecord(ReadingRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final all = [...await loadReadingRecords(), record];
    final bounded = all.length > _recordCap
        ? all.sublist(all.length - _recordCap)
        : all;
    await prefs.setString(
      _recordsKey,
      jsonEncode([for (final r in bounded) r.toJson()]),
    );
  }

  @override
  Future<Map<String, ({String title, String text})>> loadImportedBooks()
      async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_booksKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        for (final e in map.entries)
          e.key: (
            title: (e.value as Map)['title'] as String,
            text: (e.value as Map)['text'] as String,
          ),
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> saveImportedBook(String id, String title, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final books = {
      ...await loadImportedBooks(),
      id: (title: title, text: text),
    };
    await prefs.setString(
      _booksKey,
      jsonEncode({
        for (final e in books.entries)
          e.key: {'title': e.value.title, 'text': e.value.text},
      }),
    );
  }

  @override
  Future<Set<String>> loadSavedWords() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_wordsKey) ?? const []).toSet();
  }

  @override
  Future<void> saveWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final words = {...await loadSavedWords(), word};
    await prefs.setStringList(_wordsKey, words.toList()..sort());
  }
}
