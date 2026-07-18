/// Piper offline-neural speech (Phase 15 — REAL implementation).
///
/// Piper voices run on-device through sherpa_onnx (ONNX runtime): free,
/// open source, no API keys. The voice model (~60 MB, from the sherpa-onnx
/// releases mirror of the Piper voices) is NOT bundled in git — it is
/// downloaded on first use into the app documents directory, with live
/// progress, and cached forever after.
///
/// Speech-to-text stays on the platform recognizer (Piper is TTS-only);
/// that is not a TTS fallback — audio synthesis here is Piper's.
library;

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../language/speech.dart';

/// Download/initialization state, surfaced in Voice Settings.
enum PiperStatus { idle, downloading, extracting, loading, ready, error }

/// One Piper voice per language family, served from the sherpa-onnx
/// tts-models release (converted Piper voices, MIT/CC licensed).
class _PiperVoice {
  const _PiperVoice(this.dir, this.model);

  final String dir; // archive + extracted directory name
  final String model; // onnx file inside the directory

  String get url =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      '$dir.tar.bz2';
}

const _voices = {
  'es': _PiperVoice(
    'vits-piper-es_ES-davefx-medium',
    'es_ES-davefx-medium.onnx',
  ),
  'en': _PiperVoice(
    'vits-piper-en_US-amy-medium',
    'en_US-amy-medium.onnx',
  ),
};

class PiperSpeechService implements SpeechService {
  PiperSpeechService(this._sttFallback);

  /// Platform service used ONLY for microphone/STT (Piper has no STT).
  final SpeechService _sttFallback;

  final AudioPlayer _player = AudioPlayer();
  final Map<String, sherpa.OfflineTts> _engines = {};
  final Map<String, Future<void>> _inflight = {};
  bool _bindingsReady = false;
  int _gen = 0;

  // ---- Diagnostics only (Phase-15 stability investigation). No behavior
  // change: these counters/logs expose concurrency, leaks and exceptions in
  // the phone's logcat. debugPrint is NOT stripped in release builds.
  int _active = 0; // concurrent speak() bodies in flight
  int _seq = 0; // monotonic speak id
  int _loads = 0; // how many times a voice model was actually loaded
  static void _log(String m) => debugPrint('[PIPER] $m');

  /// Live status + download progress (0..1) for Voice Settings.
  final ValueNotifier<PiperStatus> status = ValueNotifier(PiperStatus.idle);
  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<String> statusDetail = ValueNotifier('');

  @override
  SpeechEngine get engine => SpeechEngine.piper;

  @override
  bool get available => true;

  static String _base(String langCode) =>
      langCode.split('-').first.toLowerCase();

  /// Ensures the voice for [langCode] is downloaded + loaded. Kicks off the
  /// download when missing; concurrent callers share one in-flight future.
  Future<void> ensureVoice(String langCode) {
    final base = _base(langCode);
    if (_engines.containsKey(base)) {
      _log('ensureVoice($base): cache hit (loads=$_loads)');
      return Future.value();
    }
    if (_inflight.containsKey(base)) {
      _log('ensureVoice($base): joining in-flight load');
      return _inflight[base]!;
    }
    _log('ensureVoice($base): starting load');
    return _inflight[base] ??= _loadVoice(base).whenComplete(
      () => _inflight.remove(base),
    );
  }

  Future<void> _loadVoice(String base) async {
    final voice = _voices[base];
    if (voice == null) {
      status.value = PiperStatus.error;
      statusDetail.value = 'No Piper voice for "$base"';
      return;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory('${docs.path}/piper');
      final dir = Directory('${root.path}/${voice.dir}');
      final modelFile = File('${dir.path}/${voice.model}');
      if (!modelFile.existsSync()) {
        await _downloadAndExtract(voice, root);
      }
      status.value = PiperStatus.loading;
      statusDetail.value = 'Loading neural voice…';
      if (!_bindingsReady) {
        sherpa.initBindings();
        _bindingsReady = true;
      }
      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelFile.path,
            tokens: '${dir.path}/tokens.txt',
            dataDir: '${dir.path}/espeak-ng-data',
          ),
          numThreads: 2,
        ),
      );
      _engines[base] = sherpa.OfflineTts(config);
      _loads++;
      status.value = PiperStatus.ready;
      statusDetail.value = 'Piper voice ready (${voice.dir})';
      _log('LOAD ok: ${voice.dir} (total model loads this session=$_loads; '
          'expected 1 per language)');
    } catch (e, st) {
      status.value = PiperStatus.error;
      statusDetail.value = 'Voice setup failed: $e';
      _log('LOAD FAILED base=$base ex=$e');
      _log('LOAD FAILED stack:\n$st');
    }
  }

  Future<void> _downloadAndExtract(_PiperVoice voice, Directory root) async {
    status.value = PiperStatus.downloading;
    progress.value = 0;
    statusDetail.value = 'Downloading neural voice…';
    final client = HttpClient();
    try {
      // GitHub releases redirect to a CDN; HttpClient follows by default.
      final request = await client.getUrl(Uri.parse(voice.url));
      final response = await request.close();
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
      // .tar.bz2 → tar → files on disk (pure Dart, no native tools).
      final tar = BZip2Decoder().decodeBytes(bytes);
      final files = TarDecoder().decodeBytes(tar);
      for (final f in files) {
        if (!f.isFile) continue;
        final out = File('${root.path}/${f.name}');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(f.content as List<int>);
      }
      _log('DOWNLOAD ok ${voice.dir} ($received bytes)');
    } catch (e, st) {
      _log('DOWNLOAD FAILED ${voice.url} ex=$e');
      _log('DOWNLOAD FAILED stack:\n$st');
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
    double speed = 1.0,
  }) async {
    final myGen = ++_gen;
    final id = ++_seq;
    _active++;
    final sw = Stopwatch()..start();
    _log('speak#$id START gen=$myGen active=$_active len=${text.length} '
        'speed=$speed ${_active > 1 ? '*** CONCURRENT SPEAK ***' : ''}');
    try {
      final base = _base(langCode);
      // First use: start (or join) the voice download. Never falls back to
      // another TTS — until the model is ready, we stay silent and Voice
      // Settings shows the download progress.
      await ensureVoice(langCode);
      final tts = _engines[base];
      if (tts == null || myGen != _gen) {
        _log('speak#$id EXIT early (tts=${tts != null} '
            'superseded=${myGen != _gen})');
        return;
      }
      final normalized = spokenText(text);
      if (normalized.isEmpty) return;
      // Sentence-chunked synthesis: keeps latency low, gives natural breaths,
      // and lets a barge-in cancel between chunks.
      final chunks = _sentences(normalized);
      final tmp = await getTemporaryDirectory();
      for (final (i, s) in chunks.indexed) {
        if (myGen != _gen) {
          _log('speak#$id BARGE-IN before chunk$i (gen $myGen!=$_gen)');
          return;
        }
        final gsw = Stopwatch()..start();
        final audio = tts.generate(text: s, sid: 0, speed: speed);
        gsw.stop();
        // generate() runs synchronously on THIS isolate: this ms figure is
        // main-thread block time — the ANR risk on a real phone.
        _log('speak#$id chunk$i generate=${gsw.elapsedMilliseconds}ms '
            'samples=${audio.samples.length} sr=${audio.sampleRate}'
            '${gsw.elapsedMilliseconds > 800 ? ' *** MAIN-ISOLATE BLOCK ***' : ''}');
        if (myGen != _gen || audio.samples.isEmpty) return;
        final wav = '${tmp.path}/piper_$myGen$i.wav';
        sherpa.writeWave(
          filename: wav,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        if (myGen != _gen) return;
        final done = Completer<void>();
        late final StreamSubscription<void> sub;
        sub = _player.onPlayerComplete.listen((_) {
          if (!done.isCompleted) done.complete();
        });
        await _player.play(DeviceFileSource(wav));
        final timeout = Duration(
          seconds: 5 + audio.samples.length ~/ audio.sampleRate,
        );
        var timedOut = false;
        await done.future.timeout(timeout, onTimeout: () => timedOut = true);
        // A timeout here means onPlayerComplete never fired — e.g. stop()
        // was called (stop() does NOT emit complete). Diagnostic for the
        // "coroutine lingers for the whole timeout on barge-in" leak.
        if (timedOut) {
          _log('speak#$id chunk$i PLAY TIMEOUT after ${timeout.inSeconds}s '
              '(onPlayerComplete never fired — stopped or hung)');
        }
        await sub.cancel();
        if (i < chunks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      _log('speak#$id DONE in ${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      // Previously UNHANDLED — an exception here escaped as an unhandled
      // async error. Log the full trace so the crash is attributable.
      _log('speak#$id EXCEPTION ex=$e');
      _log('speak#$id stack:\n$st');
    } finally {
      _active--;
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

  @override
  Future<void> stop() async {
    _gen++; // cancels the synthesis/playback loop instantly (barge-in)
    _log('stop() gen->$_gen active=$_active');
    try {
      await _player.stop();
    } catch (e, st) {
      _log('stop() player.stop ex=$e');
      _log('stop() stack:\n$st');
    }
    await _sttFallback.stop();
  }

  @override
  Future<void> pause() async {
    _gen++;
    _log('pause() gen->$_gen active=$_active');
    try {
      await _player.pause();
    } catch (e, st) {
      _log('pause() player.pause ex=$e');
      _log('pause() stack:\n$st');
    }
  }

  @override
  Future<String?> listen({String langCode = 'es-ES'}) =>
      _sttFallback.listen(langCode: langCode);
}
