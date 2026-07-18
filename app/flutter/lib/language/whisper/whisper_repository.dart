// ignore_for_file: dangling_library_doc_comments
/// Persistence seam for the local Whisper model (Phase 23). Mirrors the
/// notebook/experience repository pattern: an interface with an in-memory
/// default and a disk-backed implementation, so the model manager stays pure
/// and testable and the store can move (Firestore, etc.) later.

/// What we remember about an installed model between launches.
class WhisperModelInfo {
  const WhisperModelInfo({
    required this.version,
    required this.sizeBytes,
    required this.path,
  });

  final String version;
  final int sizeBytes;
  final String path;

  Map<String, dynamic> toJson() => {
    'version': version,
    'sizeBytes': sizeBytes,
    'path': path,
  };

  factory WhisperModelInfo.fromJson(Map<String, dynamic> json) =>
      WhisperModelInfo(
        version: json['version'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        path: json['path'] as String,
      );
}

abstract class WhisperModelRepository {
  Future<WhisperModelInfo?> load();
  Future<void> save(WhisperModelInfo info);
  Future<void> clear();
}

/// Test/default store.
class InMemoryWhisperModelRepository implements WhisperModelRepository {
  WhisperModelInfo? _info;

  @override
  Future<WhisperModelInfo?> load() async => _info;

  @override
  Future<void> save(WhisperModelInfo info) async => _info = info;

  @override
  Future<void> clear() async => _info = null;
}
