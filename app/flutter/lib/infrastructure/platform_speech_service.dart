/// Platform speech adapter (ADR-0020): the real [SpeechService] over
/// flutter_tts + speech_to_text. This is the ONLY file that touches the
/// plugins; everything else speaks to the seam. Best-effort throughout —
/// any plugin failure degrades to a no-op / null transcript rather than
/// crashing the learner's session.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../language/speech.dart';

class PlatformSpeechService implements SpeechService {
  PlatformSpeechService();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool _sttInitTried = false;

  /// Bumped on every stop()/pause(). The clause loop in speak() checks it
  /// before each clause and bails the instant it is superseded — so a
  /// barge-in cancels the WHOLE utterance, not just the current clause.
  int _speakGen = 0;

  /// Warmer-than-default voice already chosen for a language (cached).
  final Map<String, Map<String, String>> _voiceByLang = {};
  final Set<String> _voicePicked = {};

  @override
  bool get available => true;

  @override
  SpeechEngine get engine => SpeechEngine.androidNeural;

  /// Per-language base prosody. Spanish reads clearer a touch slower with
  /// slightly higher pitch; English sits a hair faster.
  static const _prosody = {
    'es': (rate: 0.42, pitch: 1.06),
    'en': (rate: 0.45, pitch: 1.04),
  };

  @override
  Future<void> speak(
    String text, {
    String langCode = 'es-ES',
    double? rate,
    double? pitch,
  }) async {
    final myGen = ++_speakGen;
    try {
      final base = _prosody[langCode.split('-').first.toLowerCase()] ??
          (rate: 0.46, pitch: 1.06);
      final baseRate = rate ?? base.rate;
      final basePitch = pitch ?? base.pitch;
      await _tts.setLanguage(langCode);
      await _pickWarmVoice(langCode);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      // Speak clause by clause with a short breath between — the natural
      // rhythm a single long utterance lacks. Questions rise in pitch and
      // slow slightly; exclamations lift a touch too. Markdown is stripped
      // first so the engine never voices '*' or '`'.
      final normalized = spokenText(text);
      // Voice diagnostics (STEP 1/2): trace the real engine + the EXACT
      // string handed to the synthesizer. Debug builds only.
      if (kDebugMode) {
        final engine = await _tts.getDefaultEngine;
        debugPrint('[TTS] engine=$engine voice=${_voiceByLang[langCode]} '
            'locale=$langCode rate=$baseRate pitch=$basePitch gen=$myGen');
        debugPrint('[TTS] speak <<$normalized>>');
      }
      final clauses = _clauses(normalized);
      for (final (i, c) in clauses.indexed) {
        // Barge-in: stop()/pause() bumped the generation → abort the rest.
        if (myGen != _speakGen) return;
        final s = c.trim();
        if (s.isEmpty) continue;
        final isQuestion = s.contains('?') || s.contains('¿');
        final isExclaim = s.contains('!') || s.contains('¡');
        await _tts.setPitch(
          basePitch + (isQuestion ? 0.08 : (isExclaim ? 0.05 : 0.0)),
        );
        await _tts.setSpeechRate(baseRate - (isQuestion ? 0.03 : 0.0));
        await _tts.speak(s);
        if (i < clauses.length - 1) {
          // Longer breath after a sentence, shorter after a comma clause.
          final end = s[s.length - 1];
          await Future<void>.delayed(Duration(
            milliseconds: '.!?…'.contains(end) ? 320 : 170,
          ));
        }
      }
    } catch (_) {
      // No TTS engine on this device — silently skip.
    }
  }

  /// Splits into clause chunks on sentence enders AND commas/semicolons/
  /// colons, keeping the punctuation so each chunk carries its intonation
  /// and gets its own breath.
  List<String> _clauses(String text) {
    final out = <String>[];
    final buf = StringBuffer();
    for (final ch in text.split('')) {
      buf.write(ch);
      if ('.!?…,;:'.contains(ch)) {
        out.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out.isEmpty ? [text] : out;
  }

  /// Picks the most natural available voice for [langCode] once: prefers
  /// enhanced/neural/network voices, else any voice for the locale.
  Future<void> _pickWarmVoice(String langCode) async {
    if (_voicePicked.contains(langCode)) {
      final v = _voiceByLang[langCode];
      if (v != null) await _tts.setVoice(v);
      return;
    }
    _voicePicked.add(langCode);
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final base = langCode.split('-').first.toLowerCase();
      final voices = [
        for (final v in raw)
          if (v is Map)
            {
              'name': '${v['name'] ?? ''}',
              'locale': '${v['locale'] ?? ''}',
            },
      ].where((v) => v['locale']!.toLowerCase().startsWith(base)).toList();
      if (voices.isEmpty) return;
      bool warm(Map<String, String> v) {
        final n = v['name']!.toLowerCase();
        return n.contains('enhanced') ||
            n.contains('neural') ||
            n.contains('network') ||
            n.contains('premium');
      }
      final wantLocale = langCode.toLowerCase().replaceAll('_', '-');
      bool exact(Map<String, String> v) =>
          v['locale']!.toLowerCase().replaceAll('_', '-') == wantLocale;
      // Prefer the exact locale (es-ES stays Castilian, not es-US), and a
      // warm/network voice within it — before falling back to the base
      // language. Wrong-accent voices were the biggest audible mismatch.
      final chosen = voices.firstWhere(
        (v) => exact(v) && warm(v),
        orElse: () => voices.firstWhere(
          exact,
          orElse: () => voices.firstWhere(warm, orElse: () => voices.first),
        ),
      );
      _voiceByLang[langCode] = chosen;
      await _tts.setVoice(chosen);
    } catch (_) {
      // getVoices unsupported (e.g. some web engines) — keep the default.
    }
  }

  @override
  Future<void> stop() async {
    _speakGen++; // cancel any in-flight clause loop (barge-in)
    if (kDebugMode) debugPrint('[TTS] stop() → gen=$_speakGen (barge-in)');
    try {
      await _tts.stop();
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    _speakGen++; // halt the clause loop too
    // Best-effort: flutter_tts pause support varies by engine; fall back to
    // a hard stop so playback always halts immediately.
    try {
      await _tts.pause();
    } catch (_) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  @override
  Future<String?> listen({String langCode = 'es-ES'}) async {
    try {
      if (!_sttInitTried) {
        _sttInitTried = true;
        _sttReady = await _stt.initialize();
      }
      if (!_sttReady) return null;
      final completer = Completer<String?>();
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          partialResults: false,
          localeId: langCode,
        ),
        onResult: (r) {
          if (r.finalResult && !completer.isCompleted) {
            completer.complete(r.recognizedWords);
          }
        },
      );
      // Guard against a mic that never returns a final result.
      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () async {
          await _stt.stop();
          return _stt.lastRecognizedWords.isEmpty
              ? null
              : _stt.lastRecognizedWords;
        },
      );
    } catch (_) {
      return null;
    }
  }
}
