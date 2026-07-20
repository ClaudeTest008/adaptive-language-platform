import 'dart:typed_data';

import 'package:adaptive_language_platform/infrastructure/piper_speech_service.dart';
import 'package:adaptive_language_platform/infrastructure/sherpa_whisper_service.dart';
import 'package:adaptive_language_platform/language/whisper/pcm.dart';
import 'package:adaptive_language_platform/language/whisper/whisper_model_manager.dart';
import 'package:adaptive_language_platform/language/whisper/whisper_repository.dart';
import 'package:adaptive_language_platform/language/whisper/whisper_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 37 — deterministic tests for the real-Whisper capture path. The mic
/// and the sherpa isolate are device-only; everything pure or fallback-routed
/// is verified here.
class _NeverDownloader implements ModelDownloader {
  @override
  Future<String> download(String url,
          {required void Function(double progress) onProgress}) =>
      throw StateError('no network in tests');

  @override
  Future<bool> verify(String path, {required int expectedBytes}) async => false;

  @override
  Future<void> delete(String path) async {}
}

void main() {
  group('pcm16BytesToFloat32', () {
    test('converts little-endian int16 to normalized floats', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, // 0
        0xFF, 0x7F, // 32767 → ~1.0
        0x00, 0x80, // -32768 → -1.0
      ]);
      final f = pcm16BytesToFloat32(bytes);
      expect(f, hasLength(3));
      expect(f[0], 0);
      expect(f[1], closeTo(0.99996, 1e-4));
      expect(f[2], -1.0);
    });

    test('ignores an odd trailing byte', () {
      final f = pcm16BytesToFloat32(Uint8List.fromList([0x00, 0x00, 0x12]));
      expect(f, hasLength(1));
    });
  });

  group('rmsOf', () {
    test('silence is 0, full-scale square wave is 1', () {
      expect(rmsOf(Float32List.fromList([0, 0, 0, 0])), 0);
      expect(rmsOf(Float32List.fromList([1, -1, 1, -1])), closeTo(1, 1e-6));
    });
  });

  group('SilenceDetector', () {
    test('never stops early on pure silence; caps at maxFrames', () {
      final d = SilenceDetector(maxFrames: 10);
      var stops = 0;
      for (var i = 0; i < 10; i++) {
        if (d.addFrame(0.001)) stops++;
      }
      expect(stops, 1); // only the cap fired
      expect(d.heardSpeech, isFalse);
    });

    test('stops after speech followed by trailing silence', () {
      // calibrationFrames: 0 → the pre-adaptive contract, unchanged.
      final d = SilenceDetector(
          trailingSilenceFrames: 3, maxFrames: 100, calibrationFrames: 0);
      expect(d.addFrame(0.5), isFalse); // speech
      expect(d.addFrame(0.4), isFalse);
      expect(d.addFrame(0.001), isFalse); // silence 1
      expect(d.addFrame(0.001), isFalse); // silence 2
      expect(d.addFrame(0.001), isTrue); // silence 3 → stop
      expect(d.heardSpeech, isTrue);
    });

    test('speech resets the silence run', () {
      final d = SilenceDetector(
          trailingSilenceFrames: 2, maxFrames: 100, calibrationFrames: 0);
      d.addFrame(0.5);
      d.addFrame(0.001);
      d.addFrame(0.5); // speech again — run resets
      expect(d.addFrame(0.001), isFalse);
      expect(d.addFrame(0.001), isTrue);
    });

    test('adapts to a noisy room instead of hearing it as speech', () {
      // Device finding: ambient RMS ~0.02 sat above the fixed 0.015
      // threshold, so "silence" was never detected and every capture ran the
      // full 12 s. With calibration, room noise sets the effective threshold
      // and real speech still triggers, so trailing silence now ends capture.
      final d = SilenceDetector(
          trailingSilenceFrames: 3, maxFrames: 120, calibrationFrames: 5);
      for (var i = 0; i < 5; i++) {
        expect(d.addFrame(0.02), isFalse); // calibration: noisy room
      }
      expect(d.effectiveThreshold, closeTo(0.05, 1e-9)); // 0.02 × 2.5
      expect(d.addFrame(0.02), isFalse); // ambient — NOT speech any more
      expect(d.heardSpeech, isFalse);
      d.addFrame(0.3); // real speech
      expect(d.heardSpeech, isTrue);
      d.addFrame(0.02); // back to ambient = silence 1
      d.addFrame(0.02); // 2
      expect(d.addFrame(0.02), isTrue); // 3 → stop (no more 12 s captures)
    });

    test('a quiet room keeps the configured floor', () {
      final d = SilenceDetector(calibrationFrames: 3);
      d.addFrame(0.001);
      d.addFrame(0.001);
      d.addFrame(0.001);
      expect(d.effectiveThreshold, 0.015); // floor wins over 0.0025
    });
  });

  group('SherpaWhisperService — fallback routing (no device)', () {
    SherpaWhisperService service(NoopWhisperService fallback) =>
        SherpaWhisperService(
          fallback: fallback,
          manager: WhisperModelManager(
            repository: InMemoryWhisperModelRepository(),
            downloader: _NeverDownloader(),
          ),
        );

    test('no installed model → delegates transcribe to the fallback', () async {
      final fallback = NoopWhisperService(scripted: 'hola profesor');
      final s = service(fallback);
      expect(s.usingLocalModel, isFalse);
      final r = await s.transcribe();
      expect(r!.transcript, 'hola profesor');
      // Label honestly reports the engine actually in use.
      expect(s.engineLabel, 'Noop');
    });

    test('fallback returning null propagates null (never fabricates)',
        () async {
      final s = service(NoopWhisperService(scripted: null));
      expect(await s.transcribe(), isNull);
    });

    test('isReady mirrors the fallback while no model is loaded', () {
      expect(service(NoopWhisperService(ready: true)).isReady, isTrue);
      expect(service(NoopWhisperService(ready: false)).isReady, isFalse);
    });

    test('cancel is safe with nothing running and reaches the fallback',
        () async {
      final s = service(NoopWhisperService());
      await s.cancel(); // must not throw
      await s.unload(); // must not throw
    });
  });

  group('pronunciation fixes (speech-only)', () {
    test('respells vaya family, preserves case, leaves display alone', () {
      expect(applyPronunciationFixes('Vaya, qué bien.'), 'Vaia, qué bien.');
      expect(applyPronunciationFixes('quiero que vayas'), 'quiero que vaias');
      expect(applyPronunciationFixes('vayamos juntos'), 'vaiamos juntos');
      // Not a substring match: 'vayan' untouched (not in the map).
      expect(applyPronunciationFixes('vayan'), 'vayan');
      expect(applyPronunciationFixes('la vaca come'), 'la vaca come');
    });
  });
}

