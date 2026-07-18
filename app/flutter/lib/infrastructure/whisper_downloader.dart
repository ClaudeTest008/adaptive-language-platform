import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
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

/// Streams the model archive to disk with progress, then extracts it. Resume
/// support: a partial `.part` file is reused via an HTTP range request.
class HttpModelDownloader implements ModelDownloader {
  @override
  Future<String> download(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final root = (await getApplicationSupportDirectory()).path;
    final dir = Directory('$root/whisper');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final archivePath = '${dir.path}/model.tar.bz2';
    final part = File('$archivePath.part');
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
      part.renameSync(archivePath);
    } finally {
      client.close();
    }

    // Extract on a worker isolate so decoding never blocks the UI thread.
    final outDir = await compute(_extractArchive, {
      'archive': archivePath,
      'out': dir.path,
    });
    return outDir;
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

/// Runs on a worker isolate (via `compute`). Decompresses the tar.bz2 and
/// writes files under [out]/model, returning that directory.
String _extractArchive(Map<String, String> args) {
  final bytes = File(args['archive']!).readAsBytesSync();
  final tar = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tar);
  final modelDir = '${args['out']}/model';
  for (final f in archive) {
    if (!f.isFile) continue;
    final out = File('$modelDir/${f.name.split('/').last}');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(f.content as List<int>);
  }
  return modelDir;
}
