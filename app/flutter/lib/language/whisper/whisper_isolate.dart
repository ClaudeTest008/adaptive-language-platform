// ignore_for_file: dangling_library_doc_comments
/// Background-isolate protocol for local Whisper inference (Phase 23).
///
/// Mirrors Piper's proven design (`piper_speech_service.dart`): a single
/// long-lived isolate owns the sherpa-onnx `OfflineRecognizer` (model loaded
/// once), the UI isolate sends audio samples over a SendPort and receives a
/// transcript back, so ONNX inference never runs on the UI thread → no ANR.
///
/// This file defines the pure, serializable message contract — real,
/// deterministic, and unit-testable — so the isolate entry point and the
/// service can be wired without touching the UI. The actual sherpa
/// `OfflineRecognizer` call + mic-PCM capture is the device-gated seam (needs
/// a raw-audio capture plugin + on-device verification, exactly as Piper's
/// real synthesis was staged after its scaffold). Requests are serialized and
/// cancellable via [WhisperCancel] carrying the generation token.

/// Load the model once in the isolate.
class WhisperLoadCmd {
  const WhisperLoadCmd({required this.modelPath, required this.tokensPath});

  final String modelPath;
  final String tokensPath;
}

/// Transcribe one utterance. [samples] are 16 kHz mono float PCM.
class WhisperTranscribeCmd {
  const WhisperTranscribeCmd({
    required this.gen,
    required this.samples,
    this.langCode = 'es-ES',
  });

  /// Generation token — a newer request or a [WhisperCancel] with a higher
  /// token aborts this one (no overlap, instant cancel).
  final int gen;
  final List<double> samples;
  final String langCode;
}

/// Cancel the running transcription with generation ≤ [gen].
class WhisperCancel {
  const WhisperCancel(this.gen);
  final int gen;
}

/// Result posted back from the isolate.
class WhisperTranscriptMsg {
  const WhisperTranscriptMsg({
    required this.gen,
    required this.transcript,
    this.language,
  });

  final int gen;
  final String transcript;
  final String? language;
}

/// Serialized error from the isolate — the UI falls back, never crashes.
class WhisperErrorMsg {
  const WhisperErrorMsg(this.gen, this.message);
  final int gen;
  final String message;
}
