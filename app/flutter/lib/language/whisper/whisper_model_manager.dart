import 'whisper_repository.dart';

/// Local Whisper model lifecycle (Phase 23) — pure, deterministic state
/// machine over a [WhisperModelRepository] and an injected [ModelDownloader].
/// Mirrors Piper's model handling: downloaded once, cached permanently,
/// version-checked, never redownloaded unnecessarily, deletable. All I/O is
/// behind seams so the logic is fully unit-testable without a device.

/// The Whisper model the app targets (a small multilingual model — chosen for
/// on-device size/latency; the URL is the download source).
// Whisper tiny multilingual (Spanish supported) — chosen over base for
// on-device decode latency. DEVICE-PROVEN: the tar.bz2 archive route never
// finished extracting on hardware (pure-Dart BZip2 on a 111 MB archive ran
// >25 min without completing), so the extracted int8 files are downloaded
// DIRECTLY — no archive, no extraction. Sizes are the published exact bytes.
const whisperModelVersion = 'whisper-tiny-multilingual-v2';
const whisperModelSizeBytes = 103609903; // encoder+decoder+tokens exact
const whisperModelUrl =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

/// The individual files fetched from [whisperModelUrl].
const whisperModelFiles = [
  'tiny-encoder.int8.onnx',
  'tiny-decoder.int8.onnx',
  'tiny-tokens.txt',
];

enum WhisperModelStatus { absent, downloading, ready, verifying, error }

/// Immutable snapshot of the model's state, surfaced to the settings UI.
class WhisperModelState {
  const WhisperModelState({
    required this.status,
    this.progress = 0,
    this.info,
    this.error,
  });

  final WhisperModelStatus status;

  /// 0…1 download progress (only meaningful while downloading).
  final double progress;
  final WhisperModelInfo? info;
  final String? error;

  bool get isReady => status == WhisperModelStatus.ready;

  WhisperModelState copyWith({
    WhisperModelStatus? status,
    double? progress,
    WhisperModelInfo? info,
    String? error,
  }) => WhisperModelState(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    info: info ?? this.info,
    error: error,
  );
}

/// Downloads model bytes to a local path, reporting 0…1 progress. Real impl
/// (HTTP + extract, resume support) lives in infrastructure; tests inject a
/// fake. Returns the installed path, or throws on failure.
abstract interface class ModelDownloader {
  Future<String> download(
    String url, {
    required void Function(double progress) onProgress,
  });

  /// True if the bytes at [path] are present and non-empty (integrity check).
  Future<bool> verify(String path, {required int expectedBytes});

  Future<void> delete(String path);
}

/// Pure lifecycle manager. Holds no learner state.
class WhisperModelManager {
  WhisperModelManager({
    required WhisperModelRepository repository,
    required ModelDownloader downloader,
  }) : _repo = repository,
       _downloader = downloader;

  final WhisperModelRepository _repo;
  final ModelDownloader _downloader;

  /// Current state from persistence — ready only if the stored version matches
  /// the target (a newer app version invalidates an old model).
  Future<WhisperModelState> status() async {
    final info = await _repo.load();
    if (info == null) {
      return const WhisperModelState(status: WhisperModelStatus.absent);
    }
    if (info.version != whisperModelVersion) {
      return const WhisperModelState(
        status: WhisperModelStatus.absent,
        error: 'A newer model is available.',
      );
    }
    return WhisperModelState(status: WhisperModelStatus.ready, info: info);
  }

  /// Downloads the model unless an up-to-date one is already installed.
  /// Emits state transitions through [onState].
  Future<WhisperModelState> ensureDownloaded({
    void Function(WhisperModelState state)? onState,
  }) async {
    final current = await status();
    if (current.isReady) return current;

    onState?.call(const WhisperModelState(
      status: WhisperModelStatus.downloading,
    ));
    try {
      final path = await _downloader.download(
        whisperModelUrl,
        onProgress: (p) => onState?.call(
          WhisperModelState(status: WhisperModelStatus.downloading, progress: p),
        ),
      );
      onState?.call(const WhisperModelState(
        status: WhisperModelStatus.verifying,
      ));
      final ok = await _downloader.verify(
        path,
        expectedBytes: whisperModelSizeBytes,
      );
      if (!ok) {
        final err = const WhisperModelState(
          status: WhisperModelStatus.error,
          error: 'Downloaded model failed verification.',
        );
        onState?.call(err);
        return err;
      }
      final info = WhisperModelInfo(
        version: whisperModelVersion,
        sizeBytes: whisperModelSizeBytes,
        path: path,
      );
      await _repo.save(info);
      final ready = WhisperModelState(
        status: WhisperModelStatus.ready,
        info: info,
      );
      onState?.call(ready);
      return ready;
    } catch (e) {
      final err = WhisperModelState(
        status: WhisperModelStatus.error,
        error: e.toString(),
      );
      onState?.call(err);
      return err;
    }
  }

  /// Removes the installed model and forgets it.
  Future<void> delete() async {
    final info = await _repo.load();
    if (info != null) await _downloader.delete(info.path);
    await _repo.clear();
  }

  /// Re-checks integrity of the installed model.
  Future<bool> verify() async {
    final info = await _repo.load();
    if (info == null) return false;
    return _downloader.verify(info.path, expectedBytes: info.sizeBytes);
  }

  /// Repairs a corrupt/incomplete model: verify, and if it fails, delete and
  /// download afresh (Phase 29 robustness). Returns the resulting state.
  Future<WhisperModelState> repair({
    void Function(WhisperModelState state)? onState,
  }) async {
    if (await verify()) {
      return status();
    }
    await delete();
    return ensureDownloaded(onState: onState);
  }

  /// Installed model size in bytes, or 0 when absent (storage reporting).
  Future<int> storageBytes() async => (await _repo.load())?.sizeBytes ?? 0;
}
