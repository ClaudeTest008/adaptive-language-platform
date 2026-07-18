/// Audio cache policy (Phase 27). Pure, deterministic — the cache *policy*
/// (stable hash filenames, lookup, LRU eviction) separated from any I/O so it
/// is fully testable. The real Piper wiring (persistent files, background
/// pre-generation, instant playback) lands in P28 and consumes this policy; it
/// is NOT device-verified here.
library;

/// A stable, collision-resistant filename for a synthesis request. Same
/// (text, language, voice, speed) → same key, so generated audio is reused
/// offline instead of re-synthesized.
String audioCacheKey({
  required String text,
  required String langCode,
  required String voice,
  required double speed,
}) {
  final speedTag = (speed * 100).round();
  final payload = '$langCode|$voice|$speedTag|${text.trim()}';
  // FNV-1a 64-bit — deterministic, dependency-free, good spread for filenames.
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xFFFFFFFFFFFFFFFF;
  for (final unit in payload.codeUnits) {
    hash = (hash ^ unit) & mask;
    hash = (hash * prime) & mask;
  }
  return 'tts_${langCode}_${hash.toRadixString(16).padLeft(16, '0')}.wav';
}

/// One cached audio file's bookkeeping.
class AudioCacheEntry {
  const AudioCacheEntry({
    required this.key,
    required this.sizeBytes,
    required this.lastUsedTick,
  });

  final String key;
  final int sizeBytes;

  /// Monotonic usage counter (higher = more recent). The caller supplies it
  /// so the policy stays pure (no clock).
  final int lastUsedTick;
}

/// Decides which cache entries to evict to get under [maxBytes], least-recently
/// used first. Pure — returns the keys to delete; the caller does the I/O.
List<String> evictionPlan(List<AudioCacheEntry> entries, {required int maxBytes}) {
  var total = entries.fold(0, (a, e) => a + e.sizeBytes);
  if (total <= maxBytes) return const [];
  final byAge = [...entries]
    ..sort((a, b) => a.lastUsedTick.compareTo(b.lastUsedTick));
  final evict = <String>[];
  for (final e in byAge) {
    if (total <= maxBytes) break;
    evict.add(e.key);
    total -= e.sizeBytes;
  }
  return evict;
}
