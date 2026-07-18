// ignore_for_file: dangling_library_doc_comments
/// Download seam for GGUF LLM models (Phase 25). Interface + a pure
/// SHA-checkable contract; the real HTTP/dart:io implementation lives in
/// infrastructure so the model manager stays testable.

/// Downloads a model file, reporting 0…1 progress, and returns its local path.
/// [expectedSha256] lets the implementation verify integrity during download.
abstract interface class LlmModelDownloader {
  Future<String> download(
    String url, {
    required String expectedSha256,
    required void Function(double progress) onProgress,
  });

  /// Verifies the file at [path] against [expectedSha256] and [expectedBytes].
  Future<bool> verify(
    String path, {
    required String expectedSha256,
    required int expectedBytes,
  });

  Future<void> delete(String path);
}
