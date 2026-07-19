import 'llm_downloader.dart';
import 'llm_repository.dart';

/// Local LLM model lifecycle (Phase 25) — pure, deterministic state machine,
/// mirroring the Piper and Whisper model handling. Downloaded once, SHA-
/// verified, version-checked, deletable, upgradeable; never reloaded per
/// request (the isolate owns the loaded model). All I/O is behind seams so the
/// logic is fully unit-testable without a device.

/// The interchangeable default GGUF model. Everything is abstract — swapping
/// tiny/small/medium/large is a matter of changing these constants + the URL.
// Qwen2.5-1.5B-Instruct Q4_K_M — substantially stronger wording than the
// previous 0.5B (which echoed prior replies on-device). Same qwen2
// architecture/tokenizer/chat template family, so the proven llamadart
// binding needs no changes. Real published size + SHA-256 from the official
// Qwen GGUF repository
// (huggingface.co/api/models/Qwen/Qwen2.5-1.5B-Instruct-GGUF/tree/main).
// Version bump = automatic upgrade: the manager treats the installed 0.5B as
// a version mismatch and redownloads.
const llmModelVersion = 'qwen2.5-1.5b-instruct-q4km-v1';
const llmModelType = 'Medium';
const llmModelSizeBytes = 1117320736; // 1.12 GB exact
const llmModelContextLength = 4096; // model supports 32k; capped for RAM
const llmModelSha256 =
    '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e';
const llmModelUrl =
    'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/'
    'qwen2.5-1.5b-instruct-q4_k_m.gguf';

enum LlmModelStatus {
  absent,
  downloading,
  verifying,
  ready,
  failed,
  deleting,
  corrupt,
  versionMismatch,
}

class LlmModelState {
  const LlmModelState({
    required this.status,
    this.progress = 0,
    this.info,
    this.error,
  });

  final LlmModelStatus status;
  final double progress;
  final LlmModelInfo? info;
  final String? error;

  bool get isReady => status == LlmModelStatus.ready;

  LlmModelState copyWith({
    LlmModelStatus? status,
    double? progress,
    LlmModelInfo? info,
    String? error,
  }) => LlmModelState(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    info: info ?? this.info,
    error: error,
  );
}

class LlmModelManager {
  LlmModelManager({
    required LlmModelRepository repository,
    required LlmModelDownloader downloader,
  }) : _repo = repository,
       _downloader = downloader;

  final LlmModelRepository _repo;
  final LlmModelDownloader _downloader;

  Future<LlmModelState> status() async {
    final info = await _repo.load();
    if (info == null) {
      return const LlmModelState(status: LlmModelStatus.absent);
    }
    if (info.version != llmModelVersion) {
      return LlmModelState(status: LlmModelStatus.versionMismatch, info: info);
    }
    return LlmModelState(status: LlmModelStatus.ready, info: info);
  }

  /// Downloads unless an up-to-date model is already installed. A version
  /// mismatch is treated as an upgrade (redownload).
  Future<LlmModelState> ensureDownloaded({
    void Function(LlmModelState state)? onState,
  }) async {
    final current = await status();
    if (current.isReady) return current;

    onState?.call(const LlmModelState(status: LlmModelStatus.downloading));
    try {
      final path = await _downloader.download(
        llmModelUrl,
        expectedSha256: llmModelSha256,
        onProgress: (p) => onState?.call(
          LlmModelState(status: LlmModelStatus.downloading, progress: p),
        ),
      );
      onState?.call(const LlmModelState(status: LlmModelStatus.verifying));
      final ok = await _downloader.verify(
        path,
        expectedSha256: llmModelSha256,
        expectedBytes: llmModelSizeBytes,
      );
      if (!ok) {
        final err = const LlmModelState(
          status: LlmModelStatus.corrupt,
          error: 'Downloaded model failed SHA verification.',
        );
        onState?.call(err);
        return err;
      }
      final info = LlmModelInfo(
        version: llmModelVersion,
        sizeBytes: llmModelSizeBytes,
        path: path,
        sha256: llmModelSha256,
        contextLength: llmModelContextLength,
        modelType: llmModelType,
      );
      await _repo.save(info);
      final ready = LlmModelState(status: LlmModelStatus.ready, info: info);
      onState?.call(ready);
      return ready;
    } catch (e) {
      final err = LlmModelState(
        status: LlmModelStatus.failed,
        error: e.toString(),
      );
      onState?.call(err);
      return err;
    }
  }

  Future<void> delete({void Function(LlmModelState state)? onState}) async {
    onState?.call(const LlmModelState(status: LlmModelStatus.deleting));
    final info = await _repo.load();
    if (info != null) await _downloader.delete(info.path);
    await _repo.clear();
    onState?.call(const LlmModelState(status: LlmModelStatus.absent));
  }

  Future<bool> verify() async {
    final info = await _repo.load();
    if (info == null) return false;
    return _downloader.verify(
      info.path,
      expectedSha256: info.sha256,
      expectedBytes: info.sizeBytes,
    );
  }
}
