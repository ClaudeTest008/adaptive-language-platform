/// Piper offline-neural speech adapter (Phase 15) — SCAFFOLD.
///
/// Piper (https://github.com/rhasspy/piper) is a free, offline, open-source
/// neural TTS. Shipping it needs native binaries + an ONNX voice model
/// (tens of MB) invoked over FFI / a platform channel — real work beyond a
/// UX pass and not bundled here. This class makes the ENGINE SWAPPABLE
/// today: it implements the same [SpeechService] seam, reports
/// [SpeechEngine.piper], and delegates to a fallback (the platform engine)
/// until [piperReady] flips true once a model is installed. The UI never
/// depends on which engine is active.
library;

import '../language/speech.dart';

class PiperSpeechService implements SpeechService {
  PiperSpeechService(this._fallback);

  /// Where audio actually comes from until Piper is wired to a bundled
  /// model — the device platform engine.
  final SpeechService _fallback;

  /// True once a Piper binary + voice model are bundled and initialized.
  /// Hard-coded false: no model ships yet. Flipping this + adding the FFI
  /// synthesis call is the only remaining work; nothing else changes.
  static const bool piperReady = false;

  @override
  SpeechEngine get engine => SpeechEngine.piper;

  @override
  bool get available => _fallback.available;

  @override
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
    double speed = 1.0,
  }) {
    // TODO(piper): synthesize `spokenText(text)` with the Piper model when
    // piperReady; until then use the platform fallback so audio still works.
    return _fallback.speak(
      text,
      langCode: langCode,
      rate: rate,
      pitch: pitch,
      speed: speed,
    );
  }

  @override
  Future<void> stop() => _fallback.stop();

  @override
  Future<void> pause() => _fallback.pause();

  @override
  Future<String?> listen({String langCode = 'es-ES'}) =>
      _fallback.listen(langCode: langCode);
}
