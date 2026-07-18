import 'connections.dart';
import 'curriculum.dart';
import 'entities.dart';
import 'teacher_brain.dart';

/// Unified Language Pipeline (Phase 21). Pure, deterministic, offline.
///
/// Guarantees the strict voice rule: the target language is SPOKEN, the native
/// language is only ever SHOWN. English must never reach the Spanish TTS
/// voice, so everything bound for speech passes [speechSafeText], which keeps
/// only target-language sentences. Mentor-mode support (translations, grammar
/// notes) is extracted with [splitTeacherReply] and rendered as text below the
/// reply — never synthesized.
///
/// Also hosts the teacher-personality helpers (greeting, adaptive feedback)
/// and the reader's connection-first word explanation — all derived from the
/// Teacher Brain, never fabricated.

/// How much native-language support the teacher shows (audio is always
/// target-language only).
enum TeacherSupportMode { immersion, mentor }

/// High-frequency function words per language — enough to decide which
/// language a sentence is written in. Deliberately small and deterministic.
const Map<String, Set<String>> _functionWords = {
  'en': {
    'the', 'is', 'are', 'was', 'you', 'your', 'this', 'that', 'and', 'but',
    'have', 'has', 'not', 'with', 'for', 'means', 'use', 'when', 'what',
    'how', 'now', 'today', 'we', 'it', 'to', 'of', 'in',
  },
  'es': {
    'el', 'la', 'los', 'las', 'es', 'son', 'está', 'estás', 'tú', 'yo',
    'y', 'pero', 'tiene', 'tienes', 'tengo', 'no', 'con', 'para', 'por',
    'qué', 'cómo', 'ahora', 'hoy', 'un', 'una', 'de', 'en', 'muy', 'dime',
  },
};

int _hits(String sentence, String lang) {
  final words = sentence
      .toLowerCase()
      .split(RegExp(r'[^a-záéíóúüñ]+'))
      .where((w) => w.isNotEmpty);
  final set = _functionWords[lang] ?? const <String>{};
  return words.where(set.contains).length;
}

/// True when [sentence] reads as [nativeLang] rather than [targetLang].
bool isNativeSentence(String sentence, String targetLang, String nativeLang) {
  final native = _hits(sentence, nativeLang);
  final target = _hits(sentence, targetLang);
  return native >= 2 && native > target;
}

final _sentenceSplit = RegExp(r'(?<=[.!?…])\s+|\n+');

/// A teacher reply split into what is spoken and what is only shown.
class TeacherReplyParts {
  const TeacherReplyParts({required this.target, required this.support});

  /// Target-language body — the only text allowed to reach TTS.
  final String target;

  /// Native-language support lines (mentor mode shows them, immersion hides).
  final String support;
}

/// Splits a reply sentence-by-sentence into target-language body and
/// native-language support.
TeacherReplyParts splitTeacherReply(
  String reply,
  String targetLang,
  String nativeLang,
) {
  final target = <String>[];
  final support = <String>[];
  for (final s in reply.split(_sentenceSplit)) {
    final t = s.trim();
    if (t.isEmpty) continue;
    (isNativeSentence(t, targetLang, nativeLang) ? support : target).add(t);
  }
  return TeacherReplyParts(
    target: target.join(' '),
    support: support.join(' '),
  );
}

/// The strict voice gate: only target-language text may be spoken. Native
/// sentences are dropped, never synthesized with the target voice.
String speechSafeText(String reply, String targetLang, String nativeLang) =>
    splitTeacherReply(reply, targetLang, nativeLang).target;

final _controlChars = RegExp(r'[\x00-\x1F\x7F]');
final _leadingJunk = RegExp(r'^[\\|/~^`*_>#\s]+');

/// Cleans learner input before it reaches the tutor: control characters,
/// stray escape/pipe prefixes (seen from keyboard/dictation artifacts like
/// `\|Si`), collapsed whitespace.
String sanitizeUserInput(String raw) => raw
    .replaceAll(_controlChars, ' ')
    .replaceFirst(_leadingJunk, '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// A personal opening line from the Teacher Brain — real data only. Returns
/// the notebook's leading observation so every session starts from what the
/// teacher actually knows, not a generic greeting. Null when the notebook has
/// nothing yet (brand-new learner).
String? teacherGreeting(TeacherBrain brain) {
  final curiosity = brain.curiosities.isEmpty
      ? null
      : brain.curiosities.first.text;
  if (curiosity != null) return curiosity;
  final o = brain.notebook.observations.isEmpty
      ? null
      : brain.notebook.observations.first;
  return o?.text;
}

/// Adaptive feedback for a scored attempt, phrased by what the brain knows.
/// [score] is 0…1.
String adaptiveFeedback(double score, TeacherBrain brain) {
  final moment = brain.connectionMoments.isEmpty
      ? null
      : brain.connectionMoments.first.text;
  if (score >= 0.85) {
    return 'This is becoming automatic — well done.'
        '${moment == null ? '' : ' $moment'}';
  }
  if (score >= 0.6) {
    return 'You understood the idea — the details will settle with use.';
  }
  final pedagogy = brain.pedagogy;
  if (pedagogy != null && pedagogy.recoveryMode) {
    return "Tricky one — that's fine, we're reviewing exactly this.";
  }
  return "Not there yet — let's slow down and connect it to what you know.";
}

/// The reader's connection-first word explanation.
class WordExplanation {
  const WordExplanation({
    required this.word,
    this.teachLine,
    this.relatedNames = const [],
    this.mentalModelInsight,
    this.translation,
    this.conceptId,
  });

  final String word;

  /// Connection-based teaching line — shown FIRST when available.
  final String? teachLine;
  final List<String> relatedNames;
  final String? mentalModelInsight;

  /// Dictionary translation — shown SECOND, never first.
  final String? translation;
  final String? conceptId;

  bool get isEmpty =>
      teachLine == null && translation == null && relatedNames.isEmpty;
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u');

/// Explains [word] through the learner's own knowledge: connection first,
/// mental model when one covers the concept, dictionary translation last.
/// Derived entirely from the brain + curriculum — no invented content.
WordExplanation explainWord(
  String word,
  TeacherBrain brain,
  Curriculum curriculum,
) {
  final folded = _fold(word.trim());
  String? conceptId;
  String? translation;
  for (final node in curriculum.graph.nodes.values) {
    if (node is VocabularyConceptNode && _fold(node.lemma) == folded) {
      conceptId = node.conceptId;
      translation = node.translations[curriculum.nativeLanguage] ??
          (node.translations.isEmpty ? null : node.translations.values.first);
      break;
    }
  }

  String? teachLine;
  final related = <String>[];
  if (conceptId != null) {
    teachLine = explainByConnection(conceptId, brain.connections);
    for (final e in brain.connections.edges) {
      if (e.fromId != conceptId && e.toId != conceptId) continue;
      final otherId = e.fromId == conceptId ? e.toId : e.fromId;
      final name = brain.connections.nodes[otherId]?.name;
      if (name != null && !related.contains(name)) related.add(name);
      if (related.length >= 4) break;
    }
  }

  String? insight;
  for (final m in brain.mentalModels) {
    if (conceptId != null &&
        (m.anchorConceptId == conceptId ||
            m.relatedConceptIds.contains(conceptId))) {
      insight = m.insight;
      break;
    }
  }

  return WordExplanation(
    word: word,
    teachLine: teachLine,
    relatedNames: related,
    mentalModelInsight: insight,
    translation: translation,
    conceptId: conceptId,
  );
}
