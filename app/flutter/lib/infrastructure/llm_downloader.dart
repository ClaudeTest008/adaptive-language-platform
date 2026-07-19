import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../language/local_llm/llm_downloader.dart';
import '../language/local_llm/llm_repository.dart';

/// Disk-backed LLM model store (Phase 25), mirroring the Whisper downloader.
/// Metadata in shared_preferences; the GGUF file in app support. Device code —
/// compiles against existing deps; on-device SHA verification + real inference
/// is the P25 hardware seam.
class PrefsLlmModelRepository implements LlmModelRepository {
  static const _key = 'llm_model_info_v1';

  @override
  Future<LlmModelInfo?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LlmModelInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(LlmModelInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(info.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Streams a single GGUF file to disk with progress and SHA-256 verification.
/// Resume: a partial `.part` file is reused via an HTTP range request.
class GgufModelDownloader implements LlmModelDownloader {
  @override
  Future<String> download(
    String url, {
    required String expectedSha256,
    required void Function(double progress) onProgress,
  }) async {
    final root = (await getApplicationSupportDirectory()).path;
    final dir = Directory('$root/llm');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    // Per-model filename (evaluation framework): different specs coexist on
    // disk, so switching between candidates never re-downloads a model that
    // is already installed and hash-valid.
    final name = Uri.parse(url).pathSegments.isEmpty
        ? 'model.gguf'
        : Uri.parse(url).pathSegments.last;
    final modelPath = '${dir.path}/$name';
    final done = File(modelPath);
    if (done.existsSync() && done.lengthSync() > 1024 * 1024) {
      if (await verify(modelPath,
          expectedSha256: expectedSha256, expectedBytes: done.lengthSync())) {
        onProgress(1.0);
        return modelPath;
      }
      done.deleteSync(); // invalid remnants never get reused
    }
    final part = File('$modelPath.part');
    final existing = part.existsSync() ? part.lengthSync() : 0;

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      if (existing > 0) req.headers.add('Range', 'bytes=$existing-');
      final res = await req.close();
      final total = (res.contentLength <= 0 ? 0 : res.contentLength) + existing;
      final sink = part.openWrite(mode: FileMode.append);
      var received = existing;
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      }
      await sink.close();
      part.renameSync(modelPath);
    } finally {
      client.close();
    }
    return modelPath;
  }

  @override
  Future<bool> verify(
    String path, {
    required String expectedSha256,
    required int expectedBytes,
  }) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    if (file.lengthSync() < 1024 * 1024) return false;
    // Skip the hash compare when no real SHA is configured yet (placeholder).
    if (expectedSha256.startsWith('PLACEHOLDER')) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expectedSha256;
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
