import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../language/local_llm/llm_model_manager.dart';
import '../language_providers.dart';
import '../ui.dart';

/// Local LLM settings (Phase 25): download / delete / verify the on-device
/// language model and see its size, version, type, context length and status.
/// The teacher works offline without it (the deterministic voice words the
/// plan); the model only makes the wording feel more natural.
class LlmSettingsScreen extends ConsumerStatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  ConsumerState<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends ConsumerState<LlmSettingsScreen> {
  LlmModelState _state = const LlmModelState(status: LlmModelStatus.absent);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await ref.read(llmModelManagerProvider).status();
    if (mounted) {
      setState(() {
        _state = s;
        _loading = false;
      });
    }
  }

  Future<void> _download() => ref.read(llmModelManagerProvider).ensureDownloaded(
        onState: (s) {
          if (mounted) setState(() => _state = s);
        },
      );

  Future<void> _delete() async {
    await ref.read(llmModelManagerProvider).delete(
      onState: (s) {
        if (mounted) setState(() => _state = s);
      },
    );
    await _refresh();
  }

  String _size() => '${(llmModelSizeBytes / (1024 * 1024)).round()} MB';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('On-device teacher voice (LLM)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Text('Local language model', style: text.titleMedium),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'The teacher already decides every lesson on-device. This '
                  'optional model only makes the wording feel more natural — '
                  'it never decides what to teach. Fully offline.',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Card(
                  child: Column(
                    children: [
                      _row('Status', _statusLabel(_state.status)),
                      _row('Type', llmModelType),
                      _row('Version', llmModelVersion),
                      _row('Size', _size()),
                      _row('Context length', '$llmModelContextLength tokens'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                switch (_state.status) {
                  LlmModelStatus.downloading => LinearProgressIndicator(
                    value: _state.progress == 0 ? null : _state.progress,
                  ),
                  LlmModelStatus.ready => OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete model'),
                  ),
                  _ => FilledButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.download),
                    label: Text(
                      _state.status == LlmModelStatus.versionMismatch
                          ? 'Upgrade model · ${_size()}'
                          : 'Download model · ${_size()}',
                    ),
                  ),
                },
                if (_state.error != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(_state.error!,
                      style: text.bodySmall?.copyWith(color: scheme.error)),
                ],
              ],
            ),
    );
  }

  Widget _row(String k, String v) => ListTile(
    dense: true,
    title: Text(k),
    trailing: Text(v),
  );

  String _statusLabel(LlmModelStatus s) => switch (s) {
    LlmModelStatus.absent => 'Not installed',
    LlmModelStatus.downloading => 'Downloading…',
    LlmModelStatus.verifying => 'Verifying…',
    LlmModelStatus.ready => 'Ready',
    LlmModelStatus.failed => 'Failed',
    LlmModelStatus.deleting => 'Deleting…',
    LlmModelStatus.corrupt => 'Corrupt',
    LlmModelStatus.versionMismatch => 'Update available',
  };
}
