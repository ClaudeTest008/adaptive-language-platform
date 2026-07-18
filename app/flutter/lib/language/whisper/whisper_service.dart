import '../speech.dart';

/// Local Whisper speech-understanding seam (Phase 23). The offline speech
/// INPUT counterpart to Piper's offline speech OUTPUT — together they close a
/// fully-offline conversation loop.
///
/// This is an interface, exactly like [SpeechService] and `AiChatModel`: the
/// Teacher Brain and UI depend on the abstraction, never a concrete engine.
/// The real sherpa-onnx Whisper isolate implementation drops in behind it
/// (see `whisper_isolate.dart`) once mic-PCM capture + on-device verification
/// land; until then `FallbackWhisperService` uses the platform recognizer, so
/// speaking works today and the pipeline above never changes. P24's local LLM
/// will consume this same interface.

/// One transcription result. [confidence] and [durationMs] are null when the
/// backend did not measure them — never fabricated.
class WhisperResult {
  const WhisperResult({
    required this.transcript,
    this.confidence,
    this.durationMs,
    this.language,
  });

  final String transcript;
  final double? confidence;
  final int? durationMs;
  final String? language;

  bool get isEmpty => transcript.trim().isEmpty;
}

abstract class WhisperService {
  /// Human-readable engine name for diagnostics/settings.
  String get engineLabel;

  /// True when a usable model is loaded and ready to transcribe locally.
  bool get isReady;

  /// Records one utterance and transcribes it. [langCode] biases recognition.
  /// Returns null if nothing was captured / permission denied.
  Future<WhisperResult?> transcribe({String langCode = 'es-ES'});

  /// Cancels any in-progress recording/transcription immediately.
  Future<void> cancel();
}

/// Offline fallback: delegates to the platform [SpeechService.listen] (Android
/// SpeechRecognizer / iOS). Keeps the conversation loop working before the
/// local Whisper model is installed. Reported as a fallback, never silent.
class FallbackWhisperService implements WhisperService {
  FallbackWhisperService(this._speech);

  final SpeechService _speech;

  @override
  String get engineLabel => 'Platform recognizer (fallback)';

  @override
  bool get isReady => _speech.available;

  @override
  Future<WhisperResult?> transcribe({String langCode = 'es-ES'}) async {
    final text = await _speech.listen(langCode: langCode);
    if (text == null) return null;
    return WhisperResult(transcript: text, language: langCode);
  }

  @override
  Future<void> cancel() => _speech.stop();
}

/// Test double: returns a scripted transcript, no plugins.
class NoopWhisperService implements WhisperService {
  NoopWhisperService({this.scripted, this.ready = true});

  String? scripted;
  bool ready;

  @override
  String get engineLabel => 'Noop';

  @override
  bool get isReady => ready;

  @override
  Future<WhisperResult?> transcribe({String langCode = 'es-ES'}) async =>
      scripted == null ? null : WhisperResult(transcript: scripted!);

  @override
  Future<void> cancel() async {}
}
