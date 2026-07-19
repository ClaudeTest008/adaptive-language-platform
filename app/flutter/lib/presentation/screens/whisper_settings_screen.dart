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
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Offline speech (Whisper)'),
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
                      const SectionHeader(
                        title: 'Local speech understanding',
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        'Download the offline Whisper model to understand your '
                        'speech entirely on-device — no internet, paired with the '
                        'offline Piper voice for a fully offline conversation. '
                        'Until then the device recognizer is used (offline-capable).',
                        style: TextStyle(
                          color: tones.inkSoft,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _StatusTile(state: _state, size: _size()),
                      const SizedBox(height: AppSpace.lg),
                      switch (_state.status) {
                        WhisperModelStatus.downloading => ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value:
                                _state.progress == 0 ? null : _state.progress,
                          ),
                        ),
                        WhisperModelStatus.ready => Row(
                          children: [
                            Expanded(
                              child: _GhostButton(
                                icon: Icons.verified_outlined,
                                label: 'Verify',
                                onPressed: _verify,
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: _GhostButton(
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                onPressed: _delete,
                              ),
                            ),
                          ],
                        ),
                        _ => PrimaryButton(
                          label: 'Download model · ${_size()}',
                          icon: Icons.download,
                          onPressed: _download,
                        ),
                      },
                      if (_state.error != null) ...[
                        const SizedBox(height: AppSpace.md),
                        Text(
                          _state.error!,
                          style: TextStyle(
                            color: scheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Soft outlined secondary action (verify / delete).
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: tones.ink,
          side: BorderSide(color: tones.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
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
    final tones = AppTones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (state.status) {
      WhisperModelStatus.ready => (
        'Installed · $size',
        Icons.check_circle,
        tones.solid(AppTint.mint),
      ),
      WhisperModelStatus.downloading => (
        'Downloading… ${(state.progress * 100).round()}%',
        Icons.downloading,
        tones.solid(AppTint.sun),
      ),
      WhisperModelStatus.verifying => (
        'Verifying…',
        Icons.hourglass_top,
        tones.solid(AppTint.sun),
      ),
      WhisperModelStatus.error => ('Error', Icons.error_outline, scheme.error),
      WhisperModelStatus.absent => (
        'Not installed',
        Icons.cloud_download_outlined,
        tones.inkSoft,
      ),
    };
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
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
                  'Model $whisperModelVersion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tones.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
