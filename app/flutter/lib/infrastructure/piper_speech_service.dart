/// Piper offline-neural speech (Phase 15 — production hardening).
///
/// CONFIRMED CRASH (real device, OnePlus CPH2037 / Android 12): calling the
/// synchronous ONNX `OfflineTts.generate()` on Flutter's UI isolate froze
/// the main thread → ANR → force close.
///
/// FIX: a single long-lived background isolate owns the Piper engine (model
/// load + all inference). The UI isolate only sends text over a SendPort and
/// receives a WAV file path back, then plays it. The UI thread never runs
/// ONNX inference, so it never blocks.
///
/// - model loads exactly once (in the isolate);
/// - speech requests are serialized (one synthesis at a time);
/// - a new request / stop() cancels the current one instantly (generation
///   token) — no blocking waits, no 7 s timeout;
/// - temp WAVs, ports, the isolate and the AudioPlayer are disposed;
/// - on any Piper failure we log the full stack and fall back to the device
///   TTS for that utterance (reported, never silent).
///
/// STT stays on the platform recognizer (Piper is TTS-only) — not a TTS
/// fallback: audio synthesis here is Piper's.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../language/speech.dart';

/// Download/initialization state, surfaced in Voice Settings.
enum PiperStatus { idle, downloading, extracting, loading, ready, error }

class _PiperVoice {
  const _PiperVoice(this.dir, this.model);
  final String dir;
  final String model;
  String get url =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      '$dir.tar.bz2';
}

const _voices = {
  'es': _PiperVoice('vits-piper-es_ES-davefx-medium', 'es_ES-davefx-medium.onnx'),
  'en': _PiperVoice('vits-piper-en_US-amy-medium', 'en_US-amy-medium.onnx'),
};

// ===========================================================================
// Background isolate: owns the Piper engine. Pure FFI + dart:io (NO plugins),
// so it needs no RootIsolateToken. One OfflineTts, loaded once, reused.
// ===========================================================================

class _LoadCmd {
  const _LoadCmd(this.model, this.tokens, this.dataDir);
  final String model, tokens, dataDir;
}

class _GenCmd {
  const _GenCmd(this.reqId, this.text, this.speed, this.outPath);
  final int reqId;
  final String text;
  final double speed;
  final String outPath;
}

void _piperIsolateEntry(SendPort toMain) {
  final port = ReceivePort();
  toMain.send(port.sendPort); // handshake: give main our SendPort
  sherpa.OfflineTts? tts;
  var bindingsReady = false;

  port.listen((msg) {
    try {
      if (msg is _LoadCmd) {
        if (tts != null) {
          toMain.send({'event': 'loaded', 'reused': true});
          return;
        }
        if (!bindingsReady) {
          sherpa.initBindings();
          bindingsReady = true;
        }
        tts = sherpa.OfflineTts(
          sherpa.OfflineTtsConfig(
            model: sherpa.OfflineTtsModelConfig(
              vits: sherpa.OfflineTtsVitsModelConfig(
                model: msg.model,
                tokens: msg.tokens,
                dataDir: msg.dataDir,
              ),
              numThreads: 2,
            ),
          ),
        );
        toMain.send({'event': 'loaded', 'reused': false});
      } else if (msg is _GenCmd) {
        final engine = tts;
        if (engine == null) {
          toMain.send({'event': 'error', 'reqId': msg.reqId, 'msg': 'no engine'});
          return;
        }
        // Synchronous ONNX inference — but on THIS isolate, so the UI stays
        // responsive. One request at a time (main serializes).
        final audio = engine.generate(text: msg.text, sid: 0, speed: msg.speed);
        if (audio.samples.isEmpty) {
          toMain.send({'event': 'empty', 'reqId': msg.reqId});
          return;
        }
        sherpa.writeWave(
          filename: msg.outPath,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        toMain.send({
          'event': 'wav',
          'reqId': msg.reqId,
          'path': msg.outPath,
          'samples': audio.samples.length,
          'sr': audio.sampleRate,
        });
      } else if (msg == 'dispose') {
        tts?.free();
        tts = null;
        port.close();
      }
    } catch (e, st) {
      toMain.send({'event': 'error', 'msg': '$e', 'stack': '$st'});
    }
  });
}

// ===========================================================================
// Main-isolate service.
// ===========================================================================

class PiperSpeechService implements SpeechService {
  PiperSpeechService(this._platform);

  /// Platform service: microphone/STT, and the reported fallback voice if
  /// Piper cannot synthesize.
  final SpeechService _platform;

  final AudioPlayer _player = AudioPlayer();

  // Isolate plumbing.
  Isolate? _isolate;
  SendPort? _toIsolate;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Future<void>? _spawning;

  bool _engineReady = false;
  Future<void>? _loading;
  int _loadCount = 0;

  int _gen = 0; // barge-in / cancellation token
  int _reqCounter = 0;
  Future<void> _busy = Future.value(); // serialization chain
  String? _tmpDir;
  String? _docsDir;
  bool _disposed = false;

  final ValueNotifier<PiperStatus> status = ValueNotifier(PiperStatus.idle);
  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<String> statusDetail = ValueNotifier('');

  static void _log(String m) => debugPrint('[PIPER] $m');
  static String _base(String c) => c.split('-').first.toLowerCase();

  @override
  SpeechEngine get engine => SpeechEngine.piper;
  @override
  bool get available => true;

  // ---- isolate lifecycle -------------------------------------------------

  Future<void> _ensureIsolate() {
    if (_toIsolate != null) return Future.value();
    return _spawning ??= () async {
      final rp = ReceivePort();
      rp.listen((msg) {
        if (msg is SendPort) {
          _toIsolate = msg;
        } else if (msg is Map) {
          _events.add(msg.cast<String, dynamic>());
        }
      });
      _isolate = await Isolate.spawn(_piperIsolateEntry, rp.sendPort);
      // wait for handshake
      while (_toIsolate == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      _log('isolate spawned');
    }();
  }

  // ---- voice download + one-time load ------------------------------------

  Future<void> ensureVoice(String langCode) {
    if (_engineReady) return Future.value();
    return _loading ??= _loadVoice(_base(langCode)).whenComplete(() {
      _loading = null;
    });
  }

  Future<void> _loadVoice(String base) async {
    final voice = _voices[base];
    if (voice == null) {
      status.value = PiperStatus.error;
      statusDetail.value = 'No Piper voice for "$base"';
      return;
    }
    try {
      _docsDir ??= (await getApplicationDocumentsDirectory()).path;
      _tmpDir ??= (await getTemporaryDirectory()).path;
      final dir = '$_docsDir/piper/${voice.dir}';
      final modelFile = File('$dir/${voice.model}');
      if (!modelFile.existsSync()) {
        await _downloadAndExtract(voice, '$_docsDir/piper');
      }
      status.value = PiperStatus.loading;
      statusDetail.value = 'Loading neural voice…';
      await _ensureIsolate();
      final loaded = _events.stream.firstWhere(
        (e) => e['event'] == 'loaded' || e['event'] == 'error',
      );
      _toIsolate!.send(_LoadCmd(
        modelFile.path,
        '$dir/tokens.txt',
        '$dir/espeak-ng-data',
      ));
      final res = await loaded.timeout(const Duration(seconds: 60));
      if (res['event'] == 'error') {
        throw StateError('${res['msg']}\n${res['stack']}');
      }
      _engineReady = true;
      _loadCount++;
      status.value = PiperStatus.ready;
      statusDetail.value = 'Piper voice ready (${voice.dir})';
      _log('LOAD model ok (loadCount=$_loadCount; must stay 1) '
          'reused=${res['reused']}');
    } catch (e, st) {
      status.value = PiperStatus.error;
      statusDetail.value = 'Voice setup failed: $e';
      _log('LOAD FAILED $e');
      _log('LOAD FAILED stack:\n$st');
    }
  }

  Future<void> _downloadAndExtract(_PiperVoice voice, String root) async {
    status.value = PiperStatus.downloading;
    progress.value = 0;
    statusDetail.value = 'Downloading neural voice…';
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(voice.url))).close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for ${voice.url}');
      }
      final total = response.contentLength;
      final bytes = <int>[];
      var received = 0;
      await for (final chunk in response) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }
      status.value = PiperStatus.extracting;
      statusDetail.value = 'Unpacking voice…';
      // Off the UI thread: BZip2 + tar of ~67 MB in a one-shot isolate.
      final files = await compute(_extractArchive, bytes);
      for (final f in files.entries) {
        final out = File('$root/${f.key}');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(f.value);
      }
      _log('DOWNLOAD+EXTRACT ok ${voice.dir} ($received bytes)');
    } catch (e, st) {
      _log('DOWNLOAD FAILED ${voice.url} $e');
      _log('DOWNLOAD FAILED stack:\n$st');
      rethrow;
    } finally {
      client.close();
    }
  }

  // ---- speak (serialized; synthesis on isolate; playback on main) --------

  @override
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
    double speed = 1.0,
  }) async {
    final myGen = ++_gen; // cancels any running/queued speak
    final prev = _busy;
    final done = Completer<void>();
    _busy = done.future;
    try {
      await prev; // the previous speak exits fast (its myGen != _gen now)
    } catch (_) {}
    try {
      await _run(text, langCode, speed, myGen);
    } finally {
      done.complete();
    }
  }

  Future<void> _run(String text, String langCode, double speed, int myGen) async {
    try {
      await ensureVoice(langCode);
      if (myGen != _gen || _disposed) return;
      if (!_engineReady) {
        _log('FALLBACK device TTS: Piper engine not ready');
        await _platform.speak(text, langCode: langCode, speed: speed);
        return;
      }
      final normalized = spokenText(text);
      if (normalized.isEmpty) return;
      for (final s in _sentences(normalized)) {
        if (myGen != _gen || _disposed) return; // barge-in
        final path = await _synthesize(s, speed, myGen);
        if (path == null || myGen != _gen || _disposed) return;
        await _playFile(path, myGen);
        if (myGen != _gen || _disposed) return;
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } catch (e, st) {
      _log('speak EXCEPTION $e');
      _log('speak stack:\n$st');
      // Never crash on a voice failure — hand this utterance to device TTS.
      if (myGen == _gen && !_disposed) {
        _log('FALLBACK device TTS after exception');
        try {
          await _platform.speak(text, langCode: langCode, speed: speed);
        } catch (_) {}
      }
    }
  }

  /// One sentence → WAV path via the background isolate. Null on error/cancel.
  Future<String?> _synthesize(String sentence, double speed, int myGen) async {
    final reqId = ++_reqCounter;
    final out = '$_tmpDir/piper_$reqId.wav';
    final reply = _events.stream.firstWhere(
      (e) =>
          (e['event'] == 'wav' && e['reqId'] == reqId) ||
          (e['event'] == 'empty' && e['reqId'] == reqId) ||
          e['event'] == 'error',
    );
    final sw = Stopwatch()..start();
    _toIsolate!.send(_GenCmd(reqId, sentence, speed, out));
    final e = await reply.timeout(const Duration(seconds: 30), onTimeout: () {
      return {'event': 'error', 'msg': 'synth timeout'};
    });
    sw.stop();
    if (myGen != _gen) return null; // barged in while synthesizing
    if (e['event'] != 'wav') {
      _log('synth req$reqId ${e['event']} ${e['msg'] ?? ''}');
      if (e['event'] == 'error') throw StateError('${e['msg']}');
      return null; // empty
    }
    _log('synth req$reqId ${sw.elapsedMilliseconds}ms (isolate) '
        'samples=${e['samples']} sr=${e['sr']}');
    return e['path'] as String;
  }

  /// Play a WAV, completing the instant it finishes OR is stopped (no long
  /// timeout, so barge-in returns immediately).
  Future<void> _playFile(String path, int myGen) async {
    final done = Completer<void>();
    late final StreamSubscription<PlayerState> sub;
    sub = _player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.completed ||
          s == PlayerState.stopped ||
          s == PlayerState.disposed) {
        if (!done.isCompleted) done.complete();
      }
    });
    try {
      await _player.play(DeviceFileSource(path));
      // Safety cap only; normally resolved by state change above.
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    } catch (e) {
      _log('play error $e');
    } finally {
      await sub.cancel();
      _deleteQuiet(path);
    }
  }

  List<String> _sentences(String text) {
    final out = <String>[];
    final buf = StringBuffer();
    for (final ch in text.split('')) {
      buf.write(ch);
      if ('.!?…'.contains(ch)) {
        final s = buf.toString().trim();
        if (s.isNotEmpty) out.add(s);
        buf.clear();
      }
    }
    final rest = buf.toString().trim();
    if (rest.isNotEmpty) out.add(rest);
    return out.isEmpty ? [text] : out;
  }

  // ---- barge-in: instant, no waiting -------------------------------------

  @override
  Future<void> stop() async {
    _gen++; // running _run exits at its next guard; synth reply discarded
    _log('stop() gen->$_gen (instant barge-in)');
    try {
      await _player.stop();
    } catch (e, st) {
      _log('stop() player $e');
      _log('stop() stack:\n$st');
    }
    await _platform.stop();
  }

  @override
  Future<void> pause() async {
    _gen++;
    try {
      await _player.pause();
    } catch (_) {}
  }

  @override
  Future<String?> listen({String langCode = 'es-ES'}) =>
      _platform.listen(langCode: langCode);

  // ---- lifecycle ---------------------------------------------------------

  void dispose() {
    _disposed = true;
    _gen++;
    _toIsolate?.send('dispose');
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toIsolate = null;
    _events.close();
    _player.dispose();
    // Purge leftover temp WAVs.
    final tmp = _tmpDir;
    if (tmp != null) {
      for (final f in Directory(tmp).listSync()) {
        if (f is File && f.path.contains('piper_')) _deleteQuiet(f.path);
      }
    }
  }

  static void _deleteQuiet(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

/// Runs in a one-shot `compute` isolate: BZip2 + tar → {name: bytes}.
Map<String, List<int>> _extractArchive(List<int> bytes) {
  final tar = BZip2Decoder().decodeBytes(bytes);
  final files = TarDecoder().decodeBytes(tar);
  return {
    for (final f in files)
      if (f.isFile) f.name: f.content as List<int>,
  };
}
