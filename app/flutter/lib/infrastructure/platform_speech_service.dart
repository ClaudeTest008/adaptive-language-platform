/// Platform speech adapter (ADR-0020): the real [SpeechService] over
/// flutter_tts + speech_to_text. This is the ONLY file that touches the
/// plugins; everything else speaks to the seam. Best-effort throughout —
/// any plugin failure degrades to a no-op / null transcript rather than
/// crashing the learner's session.
library;

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../language/speech.dart';

class PlatformSpeechService implements SpeechService {
  PlatformSpeechService();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool _sttInitTried = false;

  /// Warmer-than-default voice already chosen for a language (cached).
  final Map<String, Map<String, String>> _voiceByLang = {};
  final Set<String> _voicePicked = {};

  @override
  bool get available => true;

  @override
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
  }) async {
    try {
      await _tts.setLanguage(langCode);
      await _pickWarmVoice(langCode);
      // Slightly slower than default for learners; a touch above neutral
      // pitch reads as warmer and more expressive.
      await _tts.setSpeechRate(rate ?? 0.44);
      await _tts.setPitch(pitch ?? 1.05);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (_) {
      // No TTS engine on this device — silently skip.
    }
  }

  /// Picks the most natural available voice for [langCode] once: prefers
  /// enhanced/neural/network voices, else any voice for the locale.
  Future<void> _pickWarmVoice(String langCode) async {
    if (_voicePicked.contains(langCode)) {
      final v = _voiceByLang[langCode];
      if (v != null) await _tts.setVoice(v);
      return;
    }
    _voicePicked.add(langCode);
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final base = langCode.split('-').first.toLowerCase();
      final voices = [
        for (final v in raw)
          if (v is Map)
            {
              'name': '${v['name'] ?? ''}',
              'locale': '${v['locale'] ?? ''}',
            },
      ].where((v) => v['locale']!.toLowerCase().startsWith(base)).toList();
      if (voices.isEmpty) return;
      bool warm(Map<String, String> v) {
        final n = v['name']!.toLowerCase();
        return n.contains('enhanced') ||
            n.contains('neural') ||
            n.contains('network') ||
            n.contains('premium');
      }
      final chosen = voices.firstWhere(warm, orElse: () => voices.first);
      _voiceByLang[langCode] = chosen;
      await _tts.setVoice(chosen);
    } catch (_) {
      // getVoices unsupported (e.g. some web engines) — keep the default.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<String?> listen({String langCode = 'es-ES'}) async {
    try {
      if (!_sttInitTried) {
        _sttInitTried = true;
        _sttReady = await _stt.initialize();
      }
      if (!_sttReady) return null;
      final completer = Completer<String?>();
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          partialResults: false,
          localeId: langCode,
        ),
        onResult: (r) {
          if (r.finalResult && !completer.isCompleted) {
            completer.complete(r.recognizedWords);
          }
        },
      );
      // Guard against a mic that never returns a final result.
      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () async {
          await _stt.stop();
          return _stt.lastRecognizedWords.isEmpty
              ? null
              : _stt.lastRecognizedWords;
        },
      );
    } catch (_) {
      return null;
    }
  }
}
