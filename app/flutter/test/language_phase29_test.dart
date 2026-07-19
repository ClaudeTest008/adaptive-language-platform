import 'dart:io';

import 'package:adaptive_language_platform/infrastructure/piper_audio_cache.dart';
import 'package:adaptive_language_platform/language/pipeline.dart';
import 'package:adaptive_language_platform/language/speaking_session.dart';
import 'package:adaptive_language_platform/language/whisper/whisper_model_manager.dart';
import 'package:adaptive_language_platform/language/whisper/whisper_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDownloader implements ModelDownloader {
  _FakeDownloader({this.verifyOk = true});
  bool verifyOk;
  int downloads = 0;

  @override
  Future<String> download(String url,
      {required void Function(double) onProgress}) async {
    downloads++;
    onProgress(1.0);
    return '/models/whisper';
  }

  @override
  Future<bool> verify(String path, {required int expectedBytes}) async =>
      verifyOk;

  @override
  Future<void> delete(String path) async {}
}

void main() {
  group('speaking analytics — upgraded, measured only', () {
    test('self-corrections and restarts are counted from the transcript', () {
      final s = analyzeSpeaking(
        'tengo mucha hambre',
        'yo yo tengo no digo tengo mucha hambre',
        retries: 0,
      );
      expect(s.restarts, greaterThanOrEqualTo(1)); // "yo yo"
      expect(s.selfCorrections, greaterThanOrEqualTo(1)); // "no digo"
      expect(s.completed, isTrue);
    });

    test('speech rate + latency only when measured; else null', () {
      final withTiming = analyzeSpeaking(
        'hola mundo', 'hola mundo',
        durationMs: 2000, responseLatencyMs: 800);
      expect(withTiming.speechRateWpm, 60.0); // 2 words / 2s = 60 wpm
      expect(withTiming.responseLatencyMs, 800);

      final noTiming = analyzeSpeaking('hola', 'hola');
      expect(noTiming.speechRateWpm, isNull);
      expect(noTiming.responseLatencyMs, isNull);
    });

    test('self-corrections lower behavioural confidence', () {
      final clean = analyzeSpeaking('tengo hambre', 'tengo hambre');
      final messy =
          analyzeSpeaking('tengo hambre', 'tengo no digo tengo hambre');
      expect(messy.confidence, lessThan(clean.confidence!));
    });
  });

  group('piper cache: metric-free prefetch probe (P28 fix)', () {
    late Directory tmp;
    late PiperAudioCache cache;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('p29cache');
      cache = PiperAudioCache('${tmp.path}/c');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('has() does not affect hit/miss metrics; contains() does', () {
      cache.has('x.wav'); // probe — no metric change
      expect(cache.hits, 0);
      expect(cache.misses, 0);
      cache.contains('x.wav'); // real lookup — a miss
      expect(cache.misses, 1);
    });
  });

  group('whisper model manager — repair + storage', () {
    test('repair redownloads when verification fails', () async {
      final repo = InMemoryWhisperModelRepository();
      final dl = _FakeDownloader(verifyOk: true);
      final mgr = WhisperModelManager(repository: repo, downloader: dl);
      await mgr.ensureDownloaded();
      expect(dl.downloads, 1);
      // Now corrupt: verification fails → repair deletes + redownloads.
      dl.verifyOk = false;
      await mgr.repair();
      // delete cleared the repo, ensureDownloaded ran again (download #2 →
      // verify false → corrupt, but a download WAS attempted).
      expect(dl.downloads, greaterThanOrEqualTo(2));
    });

    test('repair is a no-op when the model verifies', () async {
      final repo = InMemoryWhisperModelRepository();
      final dl = _FakeDownloader(verifyOk: true);
      final mgr = WhisperModelManager(repository: repo, downloader: dl);
      await mgr.ensureDownloaded();
      final before = dl.downloads;
      await mgr.repair();
      expect(dl.downloads, before); // healthy → nothing redownloaded
    });

    test('storageBytes reports installed size, 0 when absent', () async {
      final repo = InMemoryWhisperModelRepository();
      final mgr = WhisperModelManager(
          repository: repo, downloader: _FakeDownloader());
      expect(await mgr.storageBytes(), 0);
      await mgr.ensureDownloaded();
      expect(await mgr.storageBytes(), greaterThan(0));
    });
  });

  group('voice pipeline guarantee (regression)', () {
    test('English is never spoken by the Spanish voice', () {
      const reply = '¡Muy bien! You already know this pattern. '
          'Ahora dime: ¿tienes hambre?';
      final safe = speechSafeText(reply, 'es', 'en');
      expect(safe, contains('hambre'));
      expect(safe.toLowerCase(), isNot(contains('you already know')));
    });

    test('immersion hides native support; mentor keeps it as text', () {
      const reply = 'Tengo hambre. This means I am hungry.';
      final parts = splitTeacherReply(reply, 'es', 'en');
      expect(parts.target, contains('hambre'));
      expect(parts.support.toLowerCase(), contains('this means'));
      // Immersion speaks + shows only target; support is available to hide.
      expect(speechSafeText(reply, 'es', 'en'), isNot(contains('This means')));
    });
  });
}
