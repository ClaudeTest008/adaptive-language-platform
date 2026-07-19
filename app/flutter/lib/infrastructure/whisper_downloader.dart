import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../language/whisper/whisper_model_manager.dart';
import '../language/whisper/whisper_repository.dart';

/// Disk-backed Whisper model store (Phase 23), mirroring the Piper voice
/// download. Metadata persists in shared_preferences; the model files live in
/// the app support directory. Device code — compiles against the existing
/// deps; on-device verification is the P23 hardware seam (like Piper's real
/// synthesis was verified after its scaffold).
class PrefsWhisperModelRepository implements WhisperModelRepository {
  static const _key = 'whisper_model_info_v1';

  @override
  Future<WhisperModelInfo?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return WhisperModelInfo.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(WhisperModelInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(info.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Downloads the extracted model files DIRECTLY (Phase 37): the tar.bz2 route
/// was proven unusable on hardware — pure-Dart BZip2 on the 111 MB whisper
/// archive ran for 25+ minutes without finishing. Each file streams to disk
/// with combined progress; a partial file resumes via an HTTP range request.
class HttpModelDownloader implements ModelDownloader {
  @override
  Future<String> download(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final root = (await getApplicationSupportDirectory()).path;
    final dir = Directory('$root/whisper');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    // Clean any stale archive from the retired extraction route.
    for (final stale in ['model.tar.bz2', 'model.tar.bz2.part']) {
      final f = File('${dir.path}/$stale');
      if (f.existsSync()) f.deleteSync();
    }
    final modelDir = Directory('${dir.path}/model');
    if (!modelDir.existsSync()) modelDir.createSync(recursive: true);

    final client = HttpClient();
    try {
      var doneBytes = 0;
      for (final name in whisperModelFiles) {
        final target = File('${modelDir.path}/$name');
        final part = File('${target.path}.part');
        final existing = part.existsSync() ? part.lengthSync() : 0;
        if (target.existsSync() && target.lengthSync() > 0) {
          doneBytes += target.lengthSync();
          continue; // already fetched (resume across attempts)
        }
        final req = await client.getUrl(Uri.parse('$url/$name'));
        if (existing > 0) req.headers.add('Range', 'bytes=$existing-');
        final res = await req.close();
        if (res.statusCode >= 400) {
          throw HttpException('HTTP ${res.statusCode} for $name');
        }
        final sink = part.openWrite(mode: FileMode.append);
        var received = existing;
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(
            ((doneBytes + received) / whisperModelSizeBytes).clamp(0.0, 1.0),
          );
        }
        await sink.close();
        part.renameSync(target.path);
        doneBytes += target.lengthSync();
      }
    } finally {
      client.close();
    }
    return modelDir.path;
  }

  @override
  Future<bool> verify(String path, {required int expectedBytes}) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    // Integrity: the extracted model + tokens files exist and are non-trivial.
    final files = dir.listSync(recursive: true).whereType<File>();
    final hasModel = files.any(
      (f) => f.path.endsWith('.onnx') && f.lengthSync() > 1024 * 1024,
    );
    final hasTokens = files.any((f) => f.path.endsWith('tokens.txt'));
    return hasModel && hasTokens;
  }

  @override
  Future<void> delete(String path) async {
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

