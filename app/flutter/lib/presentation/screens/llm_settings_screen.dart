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

  String _size(LlmModelSpec spec) =>
      '${(spec.sizeBytes / (1024 * 1024)).round()} MB';

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final spec = ref.watch(selectedLlmSpecProvider);
    final ready = _state.status == LlmModelStatus.ready;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('On-device teacher voice (LLM)'),
      ),
      body: AtmosphericBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    children: [
                      const SectionHeader(title: 'Local language model'),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        'The teacher already decides every lesson on-device. This '
                        'optional model only makes the wording feel more natural — '
                        'it never decides what to teach. Fully offline.',
                        style: TextStyle(
                          color: tones.inkSoft,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      // Model-evaluation framework: pick the candidate to run.
                      // The benchmark compares candidates on identical prompts.
                      DropdownButtonFormField<LlmModelSpec>(
                        initialValue: spec,
                        decoration: const InputDecoration(labelText: 'Model'),
                        items: [
                          for (final s in llmModelSpecs)
                            DropdownMenuItem(
                              value: s,
                              child: Text(s.displayName),
                            ),
                        ],
                        onChanged: (s) async {
                          if (s == null) return;
                          await ref
                              .read(selectedLlmSpecProvider.notifier)
                              .select(s);
                          // New spec → engine reloads its file on next use.
                          await ref.read(ggufTeacherVoiceProvider).unload();
                          await _refresh();
                        },
                      ),
                      const SizedBox(height: AppSpace.lg),
                      SoftCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (ready
                                        ? tones.solid(AppTint.mint)
                                        : tones.inkSoft)
                                    .withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                ready
                                    ? Icons.check_circle
                                    : Icons.smart_toy_outlined,
                                size: 19,
                                color: ready
                                    ? tones.solid(AppTint.mint)
                                    : tones.inkSoft,
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _statusLabel(_state.status),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tones.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    spec.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tones.inkSoft,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      SoftCard(
                        child: Column(
                          children: [
                            _row('Type', spec.type),
                            _row('Version', spec.version),
                            _row('Size', _size(spec)),
                            _row(
                              'Context length',
                              '${spec.contextLength} tokens',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      switch (_state.status) {
                        LlmModelStatus.downloading => ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value:
                                _state.progress == 0 ? null : _state.progress,
                          ),
                        ),
                        LlmModelStatus.ready => SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text(
                              'Delete model',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tones.ink,
                              side: BorderSide(color: tones.hairline),
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ),
                        _ => PrimaryButton(
                          label: _state.status ==
                                  LlmModelStatus.versionMismatch
                              ? 'Switch model · ${_size(spec)}'
                              : 'Download model · ${_size(spec)}',
                          icon: Icons.download,
                          onPressed: _download,
                        ),
                      },
                      if (_state.error != null) ...[
                        const SizedBox(height: AppSpace.md),
                        Text(
                          _state.error!,
                          style: TextStyle(color: scheme.error, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _row(String k, String v) => Builder(
    builder: (context) {
      final tones = AppTones.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs + 1),
        child: Row(
          children: [
            Expanded(
              child: Text(
                k,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tones.inkSoft, fontSize: 13.5),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Flexible(
              child: Text(
                v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: tones.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    },
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
