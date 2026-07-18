import '../speaking_session.dart';
import '../teacher_brain.dart';
import 'whisper_service.dart';

/// The offline speech-in pipeline (Phase 23):
///
///   microphone → local Whisper (or fallback) → SpeakingSession analytics →
///   connection-based feedback → Teacher Brain evidence → Piper reply.
///
/// This orchestrator is pure over its inputs: it takes a [WhisperService] and
/// turns a recognized utterance into measured [SpeakingSession] evidence plus
/// teacher feedback that reinforces connections. The brain stays the single
/// source of truth — the session is evidence it derives outcomes from, not a
/// duplicate store.
class WhisperPipeline {
  const WhisperPipeline(this._whisper);

  final WhisperService _whisper;

  bool get usingLocalModel =>
      _whisper.isReady && _whisper.engineLabel != 'Platform recognizer (fallback)';

  /// Captures one spoken attempt at [target] and analyzes it. Returns null if
  /// nothing was recognized.
  Future<SpeakingSession?> capture({
    required String target,
    required String langCode,
    int retries = 0,
    String? conceptId,
  }) async {
    final result = await _whisper.transcribe(langCode: langCode);
    if (result == null || result.isEmpty) return null;
    return analyzeSpeaking(
      target,
      result.transcript,
      durationMs: result.durationMs,
      retries: retries,
      conceptId: conceptId,
    );
  }

  Future<void> cancel() => _whisper.cancel();
}

/// Teacher's spoken response to an attempt: connection-based praise when there
/// is a real family to name, otherwise honest, level-appropriate feedback.
/// Never fabricates a connection.
String feedbackFor(SpeakingSession session, TeacherBrain brain) {
  final connection = connectionFeedback(session, brain);
  if (connection != null) return connection;
  if (!session.completed) {
    return "I didn't catch that — take your time and try once more.";
  }
  if (session.pronunciation >= 0.85) return '¡Muy bien! Clear and natural.';
  if (session.pronunciation >= 0.6) {
    return 'Good — the idea is there. Let’s tighten a couple of sounds.';
  }
  return "Close. Let's slow it down and say it together.";
}
