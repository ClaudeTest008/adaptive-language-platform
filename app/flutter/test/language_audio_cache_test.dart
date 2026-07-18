import 'dart:io';

import 'package:adaptive_exam_platform/infrastructure/piper_audio_cache.dart';
import 'package:adaptive_exam_platform/language/audio_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('audio cache keys', () {
    test('stable, and carries readable lang + voice prefix', () {
      final k = audioCacheKey(
        text: 'Hola', langCode: 'es-ES', voice: 'vits-piper-es_ES-davefx-medium',
        speed: 1.0);
      expect(
        k,
        audioCacheKey(
          text: 'Hola', langCode: 'es-ES',
          voice: 'vits-piper-es_ES-davefx-medium', speed: 1.0),
      );
      expect(k.startsWith(audioCacheVoicePrefix(
          langCode: 'es-ES', voice: 'vits-piper-es_ES-davefx-medium')), isTrue);
      expect(k.endsWith('.wav'), isTrue);
    });

    test('different voice → different prefix (voice-scoped invalidation)', () {
      final a = audioCacheVoicePrefix(langCode: 'es-ES', voice: 'davefx');
      final b = audioCacheVoicePrefix(langCode: 'es-ES', voice: 'sharvard');
      expect(a, isNot(b));
    });
  });

  group('PiperAudioCache (real dart:io)', () {
    late Directory tmp;
    late PiperAudioCache cache;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('piper_cache_test');
      cache = PiperAudioCache('${tmp.path}/cache');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<String> synth(String content) async {
      final f = File('${tmp.path}/src_$content.wav');
      await f.writeAsString(content);
      return f.path;
    }

    test('store then contains; reuse without regenerating', () async {
      expect(cache.contains('a.wav'), isFalse);
      await cache.store('a.wav', await synth('audioA'));
      expect(cache.contains('a.wav'), isTrue);
      expect(File(cache.pathFor('a.wav')).readAsStringSync(), 'audioA');
    });

    test('hit rate reflects lookups (system metric, not learner data)', () {
      cache.contains('miss.wav'); // miss
      expect(cache.hitRate, 0);
    });

    test('LRU cleanup evicts oldest, never the playing file', () async {
      await cache.store('old.wav', await synth('x' * 100));
      await cache.store('mid.wav', await synth('y' * 100));
      await cache.store('new.wav', await synth('z' * 100));
      cache.touch('mid.wav');
      cache.touch('new.wav'); // old.wav is least-recently used
      await cache.cleanup(maxBytes: 150, keep: 'new.wav');
      expect(cache.contains('new.wav'), isTrue); // protected
      expect(File(cache.pathFor('old.wav')).existsSync(), isFalse); // evicted
    });

    test('voice invalidation removes only that voice', () async {
      final vA = audioCacheVoicePrefix(langCode: 'es-ES', voice: 'davefx');
      final vB = audioCacheVoicePrefix(langCode: 'es-ES', voice: 'other');
      await cache.store('${vA}1.wav', await synth('a1'));
      await cache.store('${vB}1.wav', await synth('b1'));
      await cache.invalidateVoice(langCode: 'es-ES', voice: 'davefx');
      expect(File(cache.pathFor('${vA}1.wav')).existsSync(), isFalse);
      expect(File(cache.pathFor('${vB}1.wav')).existsSync(), isTrue);
    });

    test('clear empties the cache', () async {
      await cache.store('a.wav', await synth('a'));
      await cache.clear();
      expect(cache.sizeBytes(), 0);
    });

    test('store is a no-op when src == dest (already cached)', () async {
      final dest = cache.pathFor('same.wav');
      await File(dest).writeAsString('kept');
      await cache.store('same.wav', dest);
      expect(File(dest).readAsStringSync(), 'kept');
    });
  });
}
