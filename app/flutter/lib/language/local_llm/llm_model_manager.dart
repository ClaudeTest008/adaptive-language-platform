import 'llm_downloader.dart';
import 'llm_repository.dart';

/// Local LLM model lifecycle (Phase 25) — pure, deterministic state machine,
/// mirroring the Piper and Whisper model handling. Downloaded once, SHA-
/// verified, version-checked, deletable, upgradeable; never reloaded per
/// request (the isolate owns the loaded model). All I/O is behind seams so the
/// logic is fully unit-testable without a device.

/// One installable GGUF wording model. All values are REAL published data
/// (exact bytes + SHA-256 from the hosting repo) — never placeholders.
class LlmModelSpec {
  const LlmModelSpec({
    required this.id,
    required this.displayName,
    required this.version,
    required this.type,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    this.contextLength = 4096,
    this.systemSuffix = '',
  });

  final String id;
  final String displayName;
  final String version;
  final String type;
  final String url;
  final String sha256;
  final int sizeBytes;
  final int contextLength;

  /// Model-specific chat-template control appended to the system prompt
  /// (e.g. Qwen3's `/no_think` soft switch). This is template plumbing — the
  /// evaluation prompt CONTENT stays identical across models.
  final String systemSuffix;
}

/// Baseline — official Qwen GGUF repo, proven on-device since the 1.5B
/// upgrade session (exact bytes + sha from
/// huggingface.co/api/models/Qwen/Qwen2.5-1.5B-Instruct-GGUF/tree/main).
const llmSpecQwen25 = LlmModelSpec(
  id: 'qwen2.5-1.5b',
  displayName: 'Qwen2.5 1.5B (baseline)',
  version: 'qwen2.5-1.5b-instruct-q4km-v1',
  type: 'Medium',
  url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/'
      'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  sha256: '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e',
  sizeBytes: 1117320736,
);

/// Challenger — Qwen3-1.7B Q4_K_S (the official Qwen3 GGUF repo ships only
/// Q8_0, so this uses unsloth's well-maintained quantization; exact bytes +
/// sha from huggingface.co/api/models/unsloth/Qwen3-1.7B-GGUF/tree/main).
/// `/no_think` is Qwen3's documented soft switch disabling thinking blocks —
/// required for a chat tutor so the token budget isn't burned on reasoning.
const llmSpecQwen3 = LlmModelSpec(
  id: 'qwen3-1.7b',
  displayName: 'Qwen3 1.7B (challenger)',
  version: 'qwen3-1.7b-q4ks-v1',
  type: 'Medium',
  url: 'https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/'
      'Qwen3-1.7B-Q4_K_S.gguf',
  sha256: '71eed840867db10f14b3332e3e0bf0a36b98b762c5b0bf9e091a3e00ecd21805',
  sizeBytes: 1060190784,
  systemSuffix: ' /no_think',
);

/// Candidate wording models (model-evaluation framework).
const llmModelSpecs = <LlmModelSpec>[llmSpecQwen25, llmSpecQwen3];

/// The default spec (baseline). Legacy constant aliases below keep existing
/// call sites/tests working unchanged.
const llmDefaultSpec = llmSpecQwen25;
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
    this.spec = llmDefaultSpec,
  }) : _repo = repository,
       _downloader = downloader;

  final LlmModelRepository _repo;
  final LlmModelDownloader _downloader;

  /// The model this manager installs/serves (evaluation framework: one
  /// manager per selected spec; same downloader/repo infrastructure).
  final LlmModelSpec spec;

  Future<LlmModelState> status() async {
    final info = await _repo.load();
    if (info == null) {
      return const LlmModelState(status: LlmModelStatus.absent);
    }
    if (info.version != spec.version) {
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
        spec.url,
        expectedSha256: spec.sha256,
        onProgress: (p) => onState?.call(
          LlmModelState(status: LlmModelStatus.downloading, progress: p),
        ),
      );
      onState?.call(const LlmModelState(status: LlmModelStatus.verifying));
      final ok = await _downloader.verify(
        path,
        expectedSha256: spec.sha256,
        expectedBytes: spec.sizeBytes,
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
        version: spec.version,
        sizeBytes: spec.sizeBytes,
        path: path,
        sha256: spec.sha256,
        contextLength: spec.contextLength,
        modelType: spec.type,
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
