// ignore_for_file: dangling_library_doc_comments
/// Background-isolate protocol for local LLM inference (Phase 25).
///
/// Mirrors Piper's and Whisper's proven design: one long-lived isolate owns the
/// loaded GGUF model (loaded once), the UI isolate sends a prompt over a
/// SendPort and receives generated text back, so inference never runs on the UI
/// thread → no ANR. Requests are serialized and cancellable via a generation
/// token. Streaming tokens are intentionally NOT part of this contract (out of
/// scope for this phase).
///
/// This file is the pure, serializable message contract — real and testable.
/// The actual llama.cpp/GGUF binding is the device-gated seam (needs a native
/// inference plugin + on-device verification), staged exactly as Piper's real
/// synthesis and Whisper's real recognition were after their scaffolds.

/// Load the model once in the isolate.
class LlmLoadCmd {
  const LlmLoadCmd({required this.modelPath, this.contextLength = 4096});

  final String modelPath;
  final int contextLength;
}

/// Generate a completion for one prompt.
class LlmGenerateCmd {
  const LlmGenerateCmd({
    required this.gen,
    required this.system,
    required this.user,
    this.maxTokens = 256,
  });

  /// Generation token — a newer request / [LlmCancel] with a higher token
  /// aborts this one.
  final int gen;
  final String system;
  final String user;
  final int maxTokens;
}

class LlmCancel {
  const LlmCancel(this.gen);
  final int gen;
}

class LlmResultMsg {
  const LlmResultMsg(this.gen, this.text);
  final int gen;
  final String text;
}

class LlmErrorMsg {
  const LlmErrorMsg(this.gen, this.message);
  final int gen;
  final String message;
}
