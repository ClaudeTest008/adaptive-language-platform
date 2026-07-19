/// Deterministic learner-message understanding (conversation repair).
///
/// The investigation proved no layer read the learner's message: the planner
/// was brain-only and the voice was a canned rotator. This file gives the
/// pipeline a lightweight, fully deterministic reading of each message —
/// intent classification, explicit-fact extraction, and direct answers to
/// questions about facts the learner explicitly shared. No AI, no inference,
/// no invention: a fact is stored only when the learner literally stated it.
library;

enum LearnerIntent {
  greeting,
  farewell,
  question,
  confusion,
  exampleRequest,
  grammarRequest,
  vocabularyRequest,
  translationRequest,
  roleplayRequest,
  practiceRequest,
  conversationRequest,
  statement,
  unknown,
}

final _greeting = RegExp(
    r'^(hi|hello|hey|hola|buenos días|buenas|good (morning|afternoon|evening))\b',
    caseSensitive: false);
final _farewell = RegExp(
    r'\b(bye|goodbye|adiós|hasta luego|see you|nos vemos|chao)\b',
    caseSensitive: false);
final _confusion = RegExp(
    r"\b(i (do not|don'?t) understand|no entiendo|i'?m (lost|confused)|"
    r'what does that mean|no comprendo|too (hard|difficult)|can you explain that again)\b',
    caseSensitive: false);
final _example = RegExp(
    r'\b(another|different|more|otro|otra) (example|examples|ejemplo|ejemplos)\b|'
    r'\bgive me an example\b|\bun ejemplo\b',
    caseSensitive: false);
final _grammar = RegExp(
    r'\b(explain|why|how does|difference between|cuándo se usa|por qué)\b.*'
    r'\b(ser|estar|tener|verb|tense|grammar|conjugat|gramática|subjunctive|por|para)\b|'
    r'\bgrammar\b',
    caseSensitive: false);
final _vocab = RegExp(
    r'\b(what (does|do)|meaning of|mean in|how do (you|i) say|cómo se dice|'
    r'what is the word|vocabulary|qué significa)\b',
    caseSensitive: false);
final _translation = RegExp(
    r'\b(translate|translation|in english|en español|in spanish)\b',
    caseSensitive: false);
final _roleplay = RegExp(
    r'\b(role-?play|pretend|practice (ordering|buying|asking|checking)|'
    r'can we practice \w+ing|simulat|escena|imagina que)\b',
    caseSensitive: false);
final _practice = RegExp(
    r'\b(practice|practise|exercise|drill|quiz me|test me|practicar)\b',
    caseSensitive: false);
final _conversation = RegExp(
    r"\b(let'?s (talk|chat)|can we talk|hablemos|conversation about)\b",
    caseSensitive: false);

/// Classifies one learner message. Order matters: specific requests win over
/// the generic question/statement split. Deterministic by construction.
LearnerIntent classifyLearnerMessage(String raw) {
  final m = raw.trim();
  if (m.isEmpty) return LearnerIntent.unknown;
  if (_confusion.hasMatch(m)) return LearnerIntent.confusion;
  if (_roleplay.hasMatch(m)) return LearnerIntent.roleplayRequest;
  if (_example.hasMatch(m)) return LearnerIntent.exampleRequest;
  if (_translation.hasMatch(m)) return LearnerIntent.translationRequest;
  if (_grammar.hasMatch(m)) return LearnerIntent.grammarRequest;
  if (_vocab.hasMatch(m)) return LearnerIntent.vocabularyRequest;
  if (_conversation.hasMatch(m)) return LearnerIntent.conversationRequest;
  if (_practice.hasMatch(m)) return LearnerIntent.practiceRequest;
  if (_greeting.hasMatch(m)) return LearnerIntent.greeting;
  if (_farewell.hasMatch(m)) return LearnerIntent.farewell;
  if (m.endsWith('?') || m.startsWith(RegExp(r'(what|who|where|when|why|how|is|are|do|does|can|could)\b', caseSensitive: false))) {
    return LearnerIntent.question;
  }
  return LearnerIntent.statement;
}

String _clean(String s) => s
    .trim()
    .replaceAll(RegExp(r'[.,!?;:]+$'), '')
    .trim();

/// Extracts facts the learner EXPLICITLY stated in [raw]. Pattern-anchored:
/// nothing is inferred, guessed, or normalized beyond trimming punctuation.
/// Keys: name, city, country, job, children, interest, reason, goal.
Map<String, String> extractLearnerFacts(String raw) {
  final facts = <String, String>{};
  final m = raw.trim();

  void take(String key, RegExp re, {int group = 1}) {
    final match = re.firstMatch(m);
    if (match == null) return;
    final v = _clean(match.group(group) ?? '');
    if (v.isNotEmpty) facts[key] = v;
  }

  take('name',
      RegExp(r"\bmy name is ([A-ZÁÉÍÓÚÑ][\wáéíóúñ-]*)", caseSensitive: false));
  take('name', RegExp(r'\bme llamo ([A-ZÁÉÍÓÚÑ][\wáéíóúñ-]*)',
      caseSensitive: false));
  take('city', RegExp(r'\bi live in ([A-ZÁÉÍÓÚÑ][\wáéíóúñ ,-]*)',
      caseSensitive: false));
  take('city',
      RegExp(r'\bvivo en ([A-ZÁÉÍÓÚÑ][\wáéíóúñ ,-]*)', caseSensitive: false));
  take('country', RegExp(r"\bi(?:'m| am) from ([A-ZÁÉÍÓÚÑ][\wáéíóúñ ,-]*)",
      caseSensitive: false));
  take('job', RegExp(r'\bi work as an? ([\wáéíóúñ -]+)', caseSensitive: false));
  take('job', RegExp(r'\bmy job is ([\wáéíóúñ -]+)', caseSensitive: false));
  take('children',
      RegExp(r'\bi have (\w+) (?:children|kids|sons|daughters)\b',
          caseSensitive: false));
  take('wife',
      RegExp(r'\bmy wife is ([\wáéíóúñ -]+)', caseSensitive: false));
  take('husband',
      RegExp(r'\bmy husband is ([\wáéíóúñ -]+)', caseSensitive: false));
  take('interest',
      RegExp(r'\bi (?:like|love|enjoy) ((?:playing |watching )?[\wáéíóúñ -]+)',
          caseSensitive: false));
  take(
      'reason',
      RegExp(
          r"\bi(?:'m| am)? ?learning spanish because ([\wáéíóúñ ',.-]+)",
          caseSensitive: false));
  // "I am learning Spanish because of her/him" — pronominal, still explicit.
  take(
      'reason',
      RegExp(r'\blearning spanish (because of (?:her|him|them|my family))\b',
          caseSensitive: false));
  take('goal', RegExp(r'\bmy goal is (?:to )?([\wáéíóúñ ,-]+)',
      caseSensitive: false));
  return facts;
}

/// Direct, deterministic answers to questions about facts the learner
/// explicitly shared. Returns null when the question is not about a stored
/// fact — and an honest "you haven't told me" when it is, but the fact is
/// absent. Never invents.
String? answerFromFacts(String raw, Map<String, String> facts) {
  final m = raw.toLowerCase();
  String? key;
  if (RegExp(r"\bwhat('?s| is) my name\b|\bcómo me llamo\b").hasMatch(m)) {
    key = 'name';
  } else if (RegExp(r'\bwhere do i live\b|\bdónde vivo\b').hasMatch(m)) {
    key = 'city';
  } else if (RegExp(r'\bwhere am i from\b').hasMatch(m)) {
    key = 'country';
  } else if (RegExp(r'\bhow many (children|kids)\b').hasMatch(m)) {
    key = 'children';
  } else if (RegExp(r'\bwhat sports? do i (enjoy|like|play)\b|\bwhat do i like\b')
      .hasMatch(m)) {
    key = 'interest';
  } else if (RegExp(r'\bwhy am i (?:want to )?learn(?:ing)? spanish\b')
      .hasMatch(m)) {
    key = 'reason';
  } else if (RegExp(r'\bwhat is my (goal|job)\b').hasMatch(m)) {
    key = m.contains('job') ? 'job' : 'goal';
  }
  if (key == null) return null;
  final v = facts[key];
  if (v == null) {
    return switch (key) {
      'name' => "You haven't told me your name yet — ¿cómo te llamas?",
      'city' => "You haven't told me where you live yet — ¿dónde vives?",
      _ => "You haven't told me that yet — cuéntame.",
    };
  }
  // Pronominal reason ("because of her") resolves through the explicitly
  // stated spouse fact — both were literally said; nothing is invented.
  if (key == 'reason' &&
      RegExp(r'because of (her|him)$').hasMatch(v) &&
      (facts['wife'] != null || facts['husband'] != null)) {
    final who = facts['wife'] != null ? 'wife' : 'husband';
    final esWho = who == 'wife' ? 'esposa' : 'esposo';
    return 'Por tu $esWho. — Because of your $who: '
        '${who == 'wife' ? 'she' : 'he'} is ${facts[who]}.';
  }
  // Spanish leads (that part is spoken); English support follows on screen.
  return switch (key) {
    'name' => 'Te llamas $v. — Your name is $v.',
    'city' => 'Vives en $v. — You live in $v.',
    'country' => 'Eres de $v. — You are from $v.',
    'children' => 'Tienes $v hijos. — You have $v children.',
    'interest' => 'Te gusta $v. — You told me you like $v.',
    'reason' => 'Me lo contaste. — You are learning Spanish because $v.',
    'job' => 'Trabajas como $v. — You work as $v.',
    'goal' => 'Tu meta: $v. — Your goal is $v.',
    _ => v,
  };
}

/// Serializes shared facts for the teacher prompt. Empty string when none.
String factsBrief(Map<String, String> facts) {
  if (facts.isEmpty) return '';
  final order = [
    'name', 'city', 'country', 'job', 'children', 'wife', 'husband',
    'interest', 'reason', 'goal',
  ];
  final parts = [
    for (final k in order)
      if (facts[k] != null) '$k: ${facts[k]}',
  ];
  return parts.join(' · ');
}
