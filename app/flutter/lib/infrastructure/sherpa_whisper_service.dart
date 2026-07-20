import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../language/whisper/pcm.dart';
import '../language/whisper/whisper_isolate.dart';
import '../language/whisper/whisper_model_manager.dart';
import '../language/whisper/whisper_service.dart';

/// Real offline Whisper recognition (Phase 37): raw PCM mic capture (record
/// plugin, 16 kHz mono) → long-lived background isolate owning the sherpa-onnx
/// `OfflineRecognizer` (whisper tiny multilingual) → transcript. Mirrors the
/// device-verified Piper isolate design: model loads once in the isolate, the
/// UI thread never runs ONNX, cancellation is a generation token.
///
/// Honest failure ladder: no model / not loaded / mic denied / decode error →
/// delegate to [fallback] (platform recognizer) or return null. Never crashes,
/// never blocks the UI isolate.
class SherpaWhisperService implements WhisperService {
  SherpaWhisperService({
    required WhisperService fallback,
    required WhisperModelManager manager,
  })  : _fallback = fallback,
        _manager = manager;

  final WhisperService _fallback;
  final WhisperModelManager _manager;

  AudioRecorder? _recorder;
  Isolate? _isolate;
  SendPort? _cmdPort;
  final _events = StreamController<Object?>.broadcast();
  bool _loaded = false;
  bool _loading = false;
  int _gen = 0;
  int _decodeFailures = 0;

  /// Two consecutive decode failures demote the engine to the fallback until
  /// the next successful load.
  static const _maxDecodeFailures = 2;

  @override
  String get engineLabel =>
      _loaded ? 'Whisper tiny (offline, sherpa-onnx)' : _fallback.engineLabel;

  @override
  bool get isReady =>
      (_loaded && _decodeFailures < _maxDecodeFailures) || _fallback.isReady;

  bool get usingLocalModel => _loaded && _decodeFailures < _maxDecodeFailures;

  /// Loads the model into the background isolate once. Safe to call often.
  Future<bool> ensureLoaded() async {
    if (_loaded) return true;
    if (_loading) return false;
    _loading = true;
    try {
      final state = await _manager.status();
      final dir = state.info?.path;
      if (!state.isReady || dir == null) return false;
      final sw = Stopwatch()..start();
      final ready = ReceivePort();
      _isolate = await Isolate.spawn(_whisperIsolateEntry, ready.sendPort);
      final first = Completer<SendPort>();
      ready.listen((msg) {
        if (msg is SendPort && !first.isCompleted) {
          first.complete(msg);
        } else {
          _events.add(msg);
        }
      });
      _cmdPort = await first.future.timeout(const Duration(seconds: 10));
      _cmdPort!.send(WhisperLoadCmd(modelPath: dir, tokensPath: dir));
      final loadMsg = await _events.stream
          .firstWhere((m) => m == 'loaded' || m is WhisperErrorMsg)
          .timeout(const Duration(seconds: 30));
      if (loadMsg is WhisperErrorMsg) {
        debugPrint('[WHISPER] load FAILED: ${loadMsg.message}');
        await unload();
        return false;
      }
      _loaded = true;
      _decodeFailures = 0;
      debugPrint('[WHISPER] model loaded in ${sw.elapsedMilliseconds}ms: $dir');
      return true;
    } catch (e, st) {
      debugPrint('[WHISPER] load FAILED: $e\n$st');
      await unload();
      return false;
    } finally {
      _loading = false;
    }
  }

  @override
  Future<WhisperResult?> transcribe({String langCode = 'es-ES'}) async {
    if (!usingLocalModel) {
      final ok = await ensureLoaded();
      if (!ok) return _fallback.transcribe(langCode: langCode);
    }
    final myGen = ++_gen;

    // ---- 1 · capture raw PCM until trailing silence / cap / cancel ----
    Float32List samples;
    int captureMs;
    try {
      final rec = _recorder ??= AudioRecorder();
      if (!await rec.hasPermission()) {
        debugPrint('[WHISPER] mic permission denied → fallback');
        return _fallback.transcribe(langCode: langCode);
      }
      final stream = await rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      final sw = Stopwatch()..start();
      final chunks = <Float32List>[];
      final gate = SilenceDetector();
      var pending = <double>[];
      const frameLen = 1600; // 100 ms at 16 kHz
      await for (final bytes in stream) {
        if (myGen != _gen) break; // cancelled
        final f = pcm16BytesToFloat32(Uint8List.fromList(bytes));
        chunks.add(f);
        pending.addAll(f);
        var stop = false;
        while (pending.length >= frameLen) {
          final frame = Float32List.fromList(pending.sublist(0, frameLen));
          pending = pending.sublist(frameLen);
          if (gate.addFrame(rmsOf(frame))) {
            stop = true;
            break;
          }
        }
        if (stop) break;
      }
      await rec.stop();
      captureMs = sw.elapsedMilliseconds;
      if (myGen != _gen) return null; // cancelled mid-capture
      if (!gate.heardSpeech) {
        debugPrint('[WHISPER] no speech detected (${captureMs}ms)');
        return null;
      }
      final total = chunks.fold<int>(0, (n, c) => n + c.length);
      samples = Float32List(total);
      var o = 0;
      for (final c in chunks) {
        samples.setAll(o, c);
        o += c.length;
      }
    } catch (e, st) {
      debugPrint('[WHISPER] capture FAILED: $e\n$st');
      return _fallback.transcribe(langCode: langCode);
    }

    // ---- 2 · decode on the background isolate ----
    try {
      final sw = Stopwatch()..start();
      _cmdPort!.send(WhisperTranscribeCmd(
        gen: myGen,
        samples: samples,
        langCode: langCode,
      ));
      final msg = await _events.stream
          .firstWhere((m) =>
              (m is WhisperTranscriptMsg && m.gen == myGen) ||
              (m is WhisperErrorMsg && m.gen == myGen))
          .timeout(const Duration(seconds: 25));
      if (myGen != _gen) return null; // cancelled while decoding
      if (msg is WhisperErrorMsg) {
        _decodeFailures++;
        debugPrint('[WHISPER] decode FAILED (#$_decodeFailures): ${msg.message}');
        return _fallback.transcribe(langCode: langCode);
      }
      final t = (msg as WhisperTranscriptMsg).transcript.trim();
      _decodeFailures = 0;
      debugPrint('[WHISPER] gen#$myGen ${samples.length} samples '
          '(${captureMs}ms audio) decoded in ${sw.elapsedMilliseconds}ms '
          '<<${t.length > 80 ? '${t.substring(0, 80)}…' : t}>>');
      if (t.isEmpty) return null;
      return WhisperResult(
        transcript: t,
        durationMs: captureMs,
        language: msg.language ?? langCode,
      );
    } on TimeoutException {
      _decodeFailures++;
      debugPrint('[WHISPER] decode TIMEOUT (#$_decodeFailures)');
      return null;
    } catch (e, st) {
      _decodeFailures++;
      debugPrint('[WHISPER] decode FAILED: $e\n$st');
      return _fallback.transcribe(langCode: langCode);
    }
  }

  @override
  Future<void> cancel() async {
    _gen++;
    _cmdPort?.send(WhisperCancel(_gen));
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _fallback.cancel();
  }

  /// Kills the isolate and frees the model memory.
  Future<void> unload() async {
    _gen++;
    _loaded = false;
    _cmdPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    debugPrint('[WHISPER] engine unloaded');
  }
}

// ---------------- isolate side ----------------

/// Long-lived worker: owns the OfflineRecognizer. [WhisperLoadCmd.modelPath]
/// carries the extracted model DIRECTORY; encoder/decoder/tokens are located
/// inside (int8 variants preferred for speed).
void _whisperIsolateEntry(SendPort out) {
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  sherpa.OfflineRecognizer? recognizer;
  var cancelledBelow = 0;

  String? find(Directory d, bool Function(String name) test) {
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final name = f.path.split(Platform.pathSeparator).last;
      if (test(name)) return f.path;
    }
    return null;
  }

  inbox.listen((msg) {
    try {
      if (msg is WhisperLoadCmd) {
        final dir = Directory(msg.modelPath);
        final encoder = find(dir,
                (n) => n.contains('encoder') && n.endsWith('.int8.onnx')) ??
            find(dir, (n) => n.contains('encoder') && n.endsWith('.onnx'));
        final decoder = find(dir,
                (n) => n.contains('decoder') && n.endsWith('.int8.onnx')) ??
            find(dir, (n) => n.contains('decoder') && n.endsWith('.onnx'));
        final tokens = find(dir, (n) => n.endsWith('tokens.txt'));
        if (encoder == null || decoder == null || tokens == null) {
          out.send(const WhisperErrorMsg(
              0, 'model files missing (encoder/decoder/tokens)'));
          return;
        }
        sherpa.initBindings();
        recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: encoder,
              decoder: decoder,
              // Bilingual tutor (Phase 5/6): the learner may speak English,
              // Spanish or a mix. An empty language string lets Whisper's
              // own language detection choose per utterance instead of
              // force-decoding English speech as Spanish (which produced
              // garbage transcripts for English input).
              language: '',
              task: 'transcribe',
            ),
            tokens: tokens,
            modelType: 'whisper',
            numThreads: 2,
            debug: false,
          ),
        ));
        out.send('loaded');
      } else if (msg is WhisperCancel) {
        cancelledBelow = msg.gen;
      } else if (msg is WhisperTranscribeCmd) {
        if (msg.gen <= cancelledBelow) return; // already cancelled
        final r = recognizer;
        if (r == null) {
          out.send(WhisperErrorMsg(msg.gen, 'model not loaded'));
          return;
        }
        final stream = r.createStream();
        stream.acceptWaveform(
          samples: Float32List.fromList(msg.samples),
          sampleRate: 16000,
        );
        r.decode(stream);
        final text = r.getResult(stream).text;
        stream.free();
        if (msg.gen <= cancelledBelow) return; // cancelled during decode
        out.send(WhisperTranscriptMsg(
          gen: msg.gen,
          transcript: text,
          // Auto-detected per utterance (see OfflineWhisperModelConfig).
          language: '',
        ));
      }
    } catch (e) {
      final gen = msg is WhisperTranscribeCmd ? msg.gen : 0;
      out.send(WhisperErrorMsg(gen, e.toString()));
    }
  });
}
