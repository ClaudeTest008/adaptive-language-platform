import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';

import '../language/local_llm/llm_prompt_builder.dart';

/// Real on-device GGUF inference (Phase 36) over llama.cpp via llamadart —
/// the neural wording generator behind the packet teacher path. It receives
/// ONLY the structured [LlmPrompt] (TeacherBrain decides, this words) and
/// returns the generated text, or null on any failure so the caller falls
/// back to the deterministic voice. Mirrors the Piper service conventions:
/// load once, generation-token cancellation, explicit unload, verbose
/// `[GGUF]` logcat lines for device verification.
class GgufTeacherVoice {
  LlamaEngine? _engine;
  String? _loadedPath;
  bool _loading = false;
  int _gen = 0;

  /// Loading progress / state for settings UI.
  final ValueNotifier<String> status = ValueNotifier('idle');

  bool get ready => _engine != null && !_loading;

  /// Loads the GGUF at [path] once; concurrent calls coalesce. Returns true
  /// when the engine is ready.
  Future<bool> ensureLoaded(String path) async {
    if (_engine != null && _loadedPath == path) return true;
    if (_loading) return false;
    _loading = true;
    status.value = 'loading';
    final sw = Stopwatch()..start();
    try {
      await _engine?.dispose();
      _engine = null;
      final engine = LlamaEngine(LlamaBackend());
      // A plain path parses as ModelSource.path (file:// is rejected).
      await engine.loadModelSource(ModelSource.parse(path));
      _engine = engine;
      _loadedPath = path;
      status.value = 'ready';
      debugPrint('[GGUF] model loaded in ${sw.elapsedMilliseconds}ms: $path');
      return true;
    } catch (e, st) {
      status.value = 'error';
      debugPrint('[GGUF] load FAILED: $e\n$st');
      _engine = null;
      _loadedPath = null;
      return false;
    } finally {
      _loading = false;
    }
  }

  /// Words the teacher's decision. Streams tokens, honours [cancel] via the
  /// generation token, trims to [maxTokens]. [onPartial] fires with the running
  /// text as each chunk arrives, so the UI can display words while the model is
  /// still generating (time-to-first-token instead of wait-for-whole-reply).
  /// Null on failure/cancel/empty — the caller falls back to the deterministic
  /// voice; nothing is invented.
  Future<String?> word(
    LlmPrompt prompt, {
    int maxTokens = 120,
    void Function(String partial)? onPartial,
  }) async {
    final engine = _engine;
    if (engine == null || _loading) return null;
    final myGen = ++_gen;
    final sw = Stopwatch()..start();
    final out = StringBuffer();
    var tokens = 0;
    var firstMs = -1;
    try {
      await for (final chunk in engine.create(
        [
          LlamaChatMessage.fromText(
            role: LlamaChatRole.system,
            text: prompt.system,
          ),
          // Conversation repair: previous turns as REAL chat messages —
          // the model finally sees the conversation, newest message last.
          for (final t in prompt.history)
            LlamaChatMessage.fromText(
              role: t.fromLearner
                  ? LlamaChatRole.user
                  : LlamaChatRole.assistant,
              text: t.text,
            ),
          LlamaChatMessage.fromText(
            role: LlamaChatRole.user,
            text: prompt.user,
          ),
        ],
        // Shorter target (~a few sentences) keeps the tutor snappy; the model
        // still stops naturally well before the cap on most turns.
        params: GenerationParams(maxTokens: maxTokens),
      )) {
        if (myGen != _gen) {
          debugPrint('[GGUF] gen#$myGen cancelled after $tokens tokens');
          return null; // barge-in / superseded turn
        }
        final text = chunk.choices.first.delta.content;
        if (text != null) {
          if (firstMs < 0) {
            firstMs = sw.elapsedMilliseconds;
            debugPrint('[GGUF] gen#$myGen first token in ${firstMs}ms');
          }
          out.write(text);
          tokens++;
          onPartial?.call(out.toString());
        }
      }
      final text = out.toString().trim();
      final ms = sw.elapsedMilliseconds;
      final tps = ms == 0 ? 0 : (tokens * 1000 / ms).toStringAsFixed(1);
      debugPrint('[GGUF] gen#$myGen $tokens chunks, first=${firstMs}ms '
          'total=${ms}ms (~$tps tok/s) '
          '<<${text.length > 80 ? '${text.substring(0, 80)}…' : text}>>');
      return text.isEmpty ? null : text;
    } catch (e, st) {
      debugPrint('[GGUF] gen#$myGen FAILED: $e\n$st');
      return null;
    }
  }

  /// Aborts any in-flight generation (the stream loop exits on next chunk).
  void cancel() => _gen++;

  /// Frees the model memory. Safe to call repeatedly.
  Future<void> unload() async {
    cancel();
    final e = _engine;
    _engine = null;
    _loadedPath = null;
    status.value = 'idle';
    await e?.dispose();
    debugPrint('[GGUF] engine unloaded');
  }
}
