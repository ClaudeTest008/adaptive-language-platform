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
    'how', 'now', 'today', 'we', 'it', 'to', 'of', 'in', 'a', 'an',
    'she', 'he', 'because', 'my', 'english',
  },
  'es': {
    'el', 'la', 'los', 'las', 'es', 'son', 'está', 'estás', 'tú', 'yo',
    'y', 'pero', 'tiene', 'tienes', 'tengo', 'no', 'con', 'para', 'por',
    'qué', 'cómo', 'ahora', 'hoy', 'un', 'una', 'de', 'en', 'muy', 'dime',
    // Conversational coverage (voice-gate accuracy): pronouns/clitics and
    // high-frequency words the teacher's own lines actually use.
    'te', 'se', 'tu', 'mi', 'su', 'le', 'lo', 'del', 'al',
    'vamos', 'hola', 'gracias', 'sí', 'más', 'aquí', 'eres', 'vives',
    'llamas', 'gusta', 'otra', 'otro', 'bien',
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
  if (native >= 2 && native > target) return true;
  // Content-heavy native fragments ("Physical and emotional states") carry
  // too few function words to trip the vote. For an accented target language
  // (es): a multi-word, all-ASCII clause with ZERO target hits is native —
  // real Spanish almost always shows a function word or an accented letter.
  if (targetLang == 'es' &&
      target == 0 &&
      native >= 1 &&
      sentence.trim().split(RegExp(r'\s+')).length >= 2 &&
      !RegExp(r'[áéíóúüñ¿¡]', caseSensitive: false).hasMatch(sentence)) {
    return true;
  }
  return false;
}

/// Sentence boundaries AND clause boundaries (colon/semicolon/dash): the
/// English-speech leak came from mixed clauses like "Muy bien. Afinemos una
/// cosa: One thing to tighten: …" being voted as ONE sentence — the Spanish
/// head outvoted the English tail, which then rode into the Spanish TTS.
/// Gating each clause separately keeps speech pure without touching what is
/// shown on screen.
final _sentenceSplit = RegExp(r'(?<=[.!?…])\s+|\n+|(?<=[:;])\s+|\s+[—–]\s+');

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
  var lastWasSupport = false;
  for (final s in reply.split(_sentenceSplit)) {
    final t = s.trim();
    if (t.isEmpty) continue;
    var native = isNativeSentence(t, targetLang, nativeLang);
    // Zero-evidence ASCII clauses ("Grammar note:", "gustar works backwards")
    // vote for neither side. Two deterministic tie-breakers keep them out of
    // the target voice: a colon-terminal ASCII intro reads as a support label,
    // and a clause directly continuing a support clause stays support.
    if (!native && targetLang == 'es' && _hits(t, targetLang) == 0 &&
        !RegExp(r'[áéíóúüñ¿¡]', caseSensitive: false).hasMatch(t)) {
      if (t.endsWith(':') || lastWasSupport) native = true;
    }
    (native ? support : target).add(t);
    lastWasSupport = native;
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

/// Human-authored translations of the deterministic voice's own Spanish
/// lines. These sentences are OURS — written in this codebase — so their
/// English halves can be authored too, not guessed. Tier between "the reply
/// already carried support" and the neural model: exact-match lookup, zero
/// cost, zero invention.
const authoredLineTranslations = <String, String>{
  // Greetings / warm-up.
  '¡Hola de nuevo! ¿Seguimos donde lo dejamos?':
      'Hello again! Shall we pick up where we left off?',
  '¡Qué bueno verte! ¿Empezamos?': 'Great to see you! Shall we begin?',
  '¡Hola! ¿Cómo va el día?': 'Hello! How is your day going?',
  'Me alegro de verte otra vez. ¿Listo?': 'Glad to see you again. Ready?',
  '¡Buenas! ¿Con qué te apetece empezar?':
      'Hi! What would you like to start with?',
  // Free-conversation openers.
  '¡Qué interesante! Cuéntame un poco más.':
      'How interesting! Tell me a bit more.',
  'Ah, ¿sí? ¿Y cómo fue eso?': 'Oh really? And how was that?',
  'Vaya, qué bien. ¿Qué más me cuentas?':
      'Well, how nice. What else can you tell me?',
  'Me alegra saberlo. ¿Desde cuándo?': 'Glad to hear it. Since when?',
  'Entiendo. ¿Y qué piensas tú de eso?':
      'I see. And what do you think about that?',
  'Suena interesante. Cuéntame los detalles.':
      'Sounds interesting. Tell me the details.',
  // Review.
  'Antes de seguir, repasemos un momento lo que ya sabes.':
      'Before we go on, let’s take a moment to review what you know.',
  'Demos un paso atrás y afiancemos lo aprendido.':
      'Let’s step back and consolidate what you’ve learned.',
  'Sin prisa: revisemos juntos antes de avanzar.':
      'No rush — let’s review together before moving on.',
  'Volvamos un momento a lo anterior; así se queda mejor.':
      'Let’s go back to the earlier point for a moment; it sticks better.',
  'Repasar no es perder tiempo. Vamos a ello.':
      'Reviewing is not wasted time. Let’s get to it.',
  // Encouragement.
  '¡Vas muy bien! Sigamos.': 'You’re doing really well! Let’s continue.',
  'Me gusta tu progreso. Continuemos.': 'I like your progress. Let’s go on.',
  '¡Un paso más y lo tienes!': 'One more step and you’ve got it!',
  'Se nota que estás practicando. Sigamos así.':
      'I can tell you’ve been practising. Let’s keep it up.',
  'Muy bien, de verdad. ¿Continuamos?': 'Really good. Shall we continue?',
  'Cada vez te sale más natural.': 'It comes out more naturally every time.',
  // Practice / challenge.
  'Tu turno: dilo con tus propias palabras.':
      'Your turn: say it in your own words.',
  'Inténtalo ahora, sin miedo.': 'Try it now — don’t be afraid.',
  'Pruébalo tú. Si sale torcido, lo arreglamos juntos.':
      'You try it. If it comes out crooked, we’ll fix it together.',
  'Ahora tú. No importa si dudas.': 'Now you. It’s fine to hesitate.',
  'Venga, dime cómo lo dirías.': 'Go on, tell me how you would say it.',
  // Roleplay flow.
  'Seguimos donde lo dejamos.': 'We pick up where we left off.',
  'Muy bien, dejamos esa escena. Cambiamos de sitio.':
      'Alright, we’ll leave that scene. Let’s change places.',
  '¡Escena completada! Lo hiciste muy bien. Seguimos hablando cuando quieras.':
      'Scene complete! You did really well. We can keep talking whenever '
          'you like.',
  '¿Recuerdas?': 'Do you remember?',
};

/// The authored English for [text] when the whole reply is made of lines the
/// deterministic voice authored — exact match first, then sentence-by-
/// sentence (a reply is often greeting + follow-up). Null when any part is
/// not ours to translate.
String? authoredTranslation(String text) {
  final whole = authoredLineTranslations[text.trim()];
  if (whole != null) return whole;
  // Sentence-wise: every sentence must be an authored line.
  final sentences = text
      .split(RegExp(r'(?<=[.!?…])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (sentences.length < 2) return null;
  // Greedy: an authored key may itself span several sentences ("¡Vas muy
  // bien! Sigamos."), so at each position try the longest run that matches.
  final parts = <String>[];
  var i = 0;
  while (i < sentences.length) {
    String? hit;
    var consumed = 0;
    for (var j = sentences.length; j > i; j--) {
      hit = authoredLineTranslations[sentences.sublist(i, j).join(' ')];
      if (hit != null) {
        consumed = j - i;
        break;
      }
    }
    if (hit == null) return null;
    parts.add(hit);
    i += consumed;
  }
  return parts.join(' ');
}

/// Deterministic word-by-word gloss of [text] from the curriculum's own
/// vocabulary translations — the honest offline fallback for the tutor's
/// Translate reveal when a reply has no native half and no neural model is
/// installed. Returns '' when no word in [text] is in the curriculum; it
/// NEVER invents a translation for an unknown word.
String vocabularyGloss(String text, Curriculum curriculum) {
  // Lemma → native translation, folded for accent-insensitive matching.
  final lexicon = <String, (String, String)>{};
  for (final node in curriculum.graph.nodes.values) {
    if (node is! VocabularyConceptNode || node.translations.isEmpty) continue;
    final translation = node.translations[curriculum.nativeLanguage] ??
        node.translations.values.first;
    lexicon.putIfAbsent(_fold(node.lemma), () => (node.lemma, translation));
  }
  final seen = <String>{};
  final pairs = <String>[];
  for (final raw in text.split(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]+'))) {
    if (raw.length < 2) continue;
    final folded = _fold(raw);
    if (!seen.add(folded)) continue;
    final hit = lexicon[folded];
    if (hit != null) pairs.add('${hit.$1} = ${hit.$2}');
  }
  return pairs.join(' · ');
}

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
