import 'dart:io';

import '../language/audio_cache.dart';

/// Persistent Piper audio cache (Phase 28). Stores synthesized WAVs on disk
/// under the stable hash filenames from `audio_cache.dart`, so identical
/// (text, language, voice, speed) audio is generated once and reused offline —
/// the library feels like a music app, not an AI synthesizing every play.
///
/// The *policy* (keys, LRU eviction) is pure and lives in `audio_cache.dart`;
/// this class is the thin dart:io layer that applies it. Recency is tracked in
/// memory per session (a monotonic tick); files never touched this session
/// count as oldest, which is the correct LRU bias.
class PiperAudioCache {
  PiperAudioCache(this.dir) {
    final d = Directory(dir);
    if (!d.existsSync()) d.createSync(recursive: true);
  }

  /// Absolute cache directory.
  final String dir;

  final Map<String, int> _tick = {};
  int _counter = 0;

  // --- system metrics (NOT learner data — never enters TeacherBrain) ---
  int hits = 0;
  int misses = 0;
  int stored = 0;

  double get hitRate {
    final total = hits + misses;
    return total == 0 ? 0 : hits / total;
  }

  String pathFor(String key) => '$dir/$key';

  /// Pure existence probe — no metric side effects. Use for prefetch checks so
  /// background probing does not distort the playback hit rate (Phase 29).
  bool has(String key) => File(pathFor(key)).existsSync();

  /// True if audio for [key] is already on disk. Counts as a hit/miss — use
  /// only on the real playback path, not for prefetch probing.
  bool contains(String key) {
    final present = File(pathFor(key)).existsSync();
    if (present) {
      hits++;
    } else {
      misses++;
    }
    return present;
  }

  /// Marks [key] as most-recently used.
  void touch(String key) => _tick[key] = ++_counter;

  /// Moves the freshly-synthesized [srcPath] into the cache under [key] and
  /// returns the cached path. If the source and destination coincide it is a
  /// no-op. The source temp file is removed after a copy.
  Future<String> store(String key, String srcPath) async {
    final dest = pathFor(key);
    if (srcPath != dest) {
      final src = File(srcPath);
      if (src.existsSync()) {
        await src.copy(dest);
        _deleteQuiet(srcPath);
      }
    }
    touch(key);
    stored++;
    return dest;
  }

  /// Removes least-recently-used files until the cache fits [maxBytes]. Never
  /// deletes [keep] (e.g. the file currently playing).
  Future<void> cleanup({required int maxBytes, String? keep}) async {
    final entries = <AudioCacheEntry>[];
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (keep != null && name == keep) continue;
      entries.add(AudioCacheEntry(
        key: name,
        sizeBytes: f.lengthSync(),
        lastUsedTick: _tick[name] ?? 0,
      ));
    }
    for (final key in evictionPlan(entries, maxBytes: maxBytes)) {
      _deleteQuiet(pathFor(key));
      _tick.remove(key);
    }
  }

  /// Invalidates only the audio for one (language, voice) — a voice change
  /// keeps every other voice's cache intact.
  Future<void> invalidateVoice({
    required String langCode,
    required String voice,
  }) async {
    final prefix = audioCacheVoicePrefix(langCode: langCode, voice: voice);
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith(prefix)) {
        _deleteQuiet(f.path);
        _tick.remove(name);
      }
    }
  }

  /// Total bytes currently cached (system metric).
  int sizeBytes() {
    var total = 0;
    for (final f in Directory(dir).listSync().whereType<File>()) {
      total += f.lengthSync();
    }
    return total;
  }

  Future<void> clear() async {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      _deleteQuiet(f.path);
    }
    _tick.clear();
  }

  static void _deleteQuiet(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
