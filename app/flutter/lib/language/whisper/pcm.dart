import 'dart:typed_data';

/// Pure PCM helpers for the Whisper capture path (Phase 37). No plugins, no
/// I/O — fully unit-testable. The mic delivers 16-bit little-endian mono PCM;
/// sherpa-onnx wants normalized Float32 samples.

/// Converts 16-bit little-endian PCM bytes to normalized floats (-1…1).
/// An odd trailing byte is ignored (incomplete frame at stream end).
Float32List pcm16BytesToFloat32(Uint8List bytes) {
  final n = bytes.lengthInBytes ~/ 2;
  final out = Float32List(n);
  final data = ByteData.sublistView(bytes, 0, n * 2);
  for (var i = 0; i < n; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Root-mean-square level of a sample window (0…1).
double rmsOf(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  return _sqrt(sum / samples.length);
}

double _sqrt(double v) {
  // Newton's method — avoids importing dart:math into a pure hot path.
  if (v <= 0) return 0;
  var x = v;
  for (var i = 0; i < 24; i++) {
    x = 0.5 * (x + v / x);
  }
  return x;
}

/// Deterministic end-of-utterance detector: stop once speech has been heard
/// and [trailingSilenceFrames] consecutive quiet frames follow, or when
/// [maxFrames] is reached. Feed it one RMS value per fixed-length frame.
class SilenceDetector {
  SilenceDetector({
    this.speechThreshold = 0.015,
    this.trailingSilenceFrames = 12,
    this.maxFrames = 120,
  });

  /// RMS above this counts as speech.
  final double speechThreshold;

  /// Quiet frames after speech that end the utterance (12 × 100 ms = 1.2 s).
  final int trailingSilenceFrames;

  /// Hard cap regardless of speech (120 × 100 ms = 12 s).
  final int maxFrames;

  bool _heardSpeech = false;
  int _silentRun = 0;
  int _frames = 0;

  bool get heardSpeech => _heardSpeech;

  /// Returns true when capture should stop.
  bool addFrame(double rms) {
    _frames++;
    if (rms >= speechThreshold) {
      _heardSpeech = true;
      _silentRun = 0;
    } else if (_heardSpeech) {
      _silentRun++;
      if (_silentRun >= trailingSilenceFrames) return true;
    }
    return _frames >= maxFrames;
  }
}
