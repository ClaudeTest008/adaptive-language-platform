import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/whisper/whisper_model_manager.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Offline speech-understanding settings (Phase 23): download, verify, delete
/// the local Whisper model and see its storage size. Until the model is
/// installed the app uses the platform recognizer (offline-capable) as a
/// labelled fallback, so speaking works throughout.
class WhisperSettingsScreen extends ConsumerStatefulWidget {
  const WhisperSettingsScreen({super.key});

  @override
  ConsumerState<WhisperSettingsScreen> createState() =>
      _WhisperSettingsScreenState();
}

class _WhisperSettingsScreenState extends ConsumerState<WhisperSettingsScreen> {
  WhisperModelState _state = const WhisperModelState(
    status: WhisperModelStatus.absent,
  );
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await ref.read(whisperModelManagerProvider).status();
    if (mounted) {
      setState(() {
        _state = s;
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    await ref.read(whisperModelManagerProvider).ensureDownloaded(
      onState: (s) {
        if (mounted) setState(() => _state = s);
      },
    );
  }

  Future<void> _delete() async {
    await ref.read(whisperModelManagerProvider).delete();
    await _refresh();
  }

  Future<void> _verify() async {
    final ok = await ref.read(whisperModelManagerProvider).verify();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Model verified.' : 'Model check failed.')),
      );
    }
  }

  String _size() =>
      '${(whisperModelSizeBytes / (1024 * 1024)).round()} MB';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline speech (Whisper)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Text('Local speech understanding', style: text.titleMedium),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Download the offline Whisper model to understand your '
                  'speech entirely on-device — no internet, paired with the '
                  'offline Piper voice for a fully offline conversation. '
                  'Until then the device recognizer is used (offline-capable).',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _StatusTile(state: _state, size: _size()),
                const SizedBox(height: AppSpace.lg),
                switch (_state.status) {
                  WhisperModelStatus.downloading => LinearProgressIndicator(
                    value: _state.progress == 0 ? null : _state.progress,
                  ),
                  WhisperModelStatus.ready => Wrap(
                    spacing: AppSpace.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _verify,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verify'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                  _ => FilledButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.download),
                    label: Text('Download model · ${_size()}'),
                  ),
                },
                if (_state.error != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    _state.error!,
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.state, required this.size});

  final WhisperModelState state;
  final String size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (state.status) {
      WhisperModelStatus.ready => ('Installed · $size', Icons.check_circle, scheme.primary),
      WhisperModelStatus.downloading => (
        'Downloading… ${(state.progress * 100).round()}%',
        Icons.downloading,
        scheme.tertiary,
      ),
      WhisperModelStatus.verifying => ('Verifying…', Icons.hourglass_top, scheme.tertiary),
      WhisperModelStatus.error => ('Error', Icons.error_outline, scheme.error),
      WhisperModelStatus.absent => ('Not installed', Icons.cloud_download_outlined, scheme.onSurfaceVariant),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: Text('Model $whisperModelVersion'),
      ),
    );
  }
}
