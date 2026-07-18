// ignore_for_file: dangling_library_doc_comments
/// Persistence seam for the local LLM model (Phase 25), mirroring the Whisper
/// model repository. Interface + in-memory default; the disk-backed impl lives
/// in infrastructure so the model manager stays pure and testable.

/// What we remember about an installed GGUF model between launches.
class LlmModelInfo {
  const LlmModelInfo({
    required this.version,
    required this.sizeBytes,
    required this.path,
    required this.sha256,
    this.contextLength,
    this.modelType,
  });

  final String version;
  final int sizeBytes;
  final String path;
  final String sha256;

  /// Tokens of context the model supports; null until known.
  final int? contextLength;

  /// Tiny / Small / Medium / Large — the interchangeable GGUF class.
  final String? modelType;

  Map<String, dynamic> toJson() => {
    'version': version,
    'sizeBytes': sizeBytes,
    'path': path,
    'sha256': sha256,
    'contextLength': contextLength,
    'modelType': modelType,
  };

  factory LlmModelInfo.fromJson(Map<String, dynamic> json) => LlmModelInfo(
    version: json['version'] as String,
    sizeBytes: (json['sizeBytes'] as num).toInt(),
    path: json['path'] as String,
    sha256: json['sha256'] as String,
    contextLength: (json['contextLength'] as num?)?.toInt(),
    modelType: json['modelType'] as String?,
  );
}

abstract class LlmModelRepository {
  Future<LlmModelInfo?> load();
  Future<void> save(LlmModelInfo info);
  Future<void> clear();
}

class InMemoryLlmModelRepository implements LlmModelRepository {
  LlmModelInfo? _info;

  @override
  Future<LlmModelInfo?> load() async => _info;

  @override
  Future<void> save(LlmModelInfo info) async => _info = info;

  @override
  Future<void> clear() async => _info = null;
}
