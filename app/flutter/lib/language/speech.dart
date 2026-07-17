/// Speech seam (ADR-0020). Provider-independent, exactly like the
/// AiChatModel seam: pure interface here, platform adapters
/// (flutter_tts + speech_to_text) in infrastructure, a fake in tests.
/// Language logic never touches a plugin.
library;

abstract class SpeechService {
  /// Text-to-speech, best-effort. [langCode] is a BCP-47 tag ('es-ES').
  /// [rate] (0..1, ~0.45 natural) and [pitch] (0.5..2, ~1.05 warm)
  /// override the service defaults per utterance.
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
  });

  /// Stops any in-progress speech.
  Future<void> stop();

  /// Listens for one utterance and returns the transcript, or null if
  /// nothing was recognized / permission denied / unsupported.
  Future<String?> listen({String langCode = 'es-ES'});

  /// False on platforms without TTS/mic (degrade the UI, never crash).
  bool get available;
}

/// No-op speech for tests and unsupported platforms. `listen` echoes an
/// optional scripted transcript so speaking flows are testable offline.
class NoopSpeechService implements SpeechService {
  NoopSpeechService({this.scriptedTranscript});

  /// What [listen] returns (simulates a recognized utterance in tests).
  String? scriptedTranscript;

  final List<String> spoken = [];

  @override
  bool get available => scriptedTranscript != null;

  @override
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
  }) async =>
      spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  Future<String?> listen({String langCode = 'es-ES'}) async =>
      scriptedTranscript;
}
