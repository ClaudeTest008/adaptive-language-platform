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

  @override
  bool get available => true;

  @override
  Future<void> speak(String text, {String langCode = 'es-ES'}) async {
    try {
      await _tts.setLanguage(langCode);
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {
      // No TTS engine on this device — silently skip.
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
