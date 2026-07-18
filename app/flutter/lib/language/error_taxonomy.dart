import 'misconceptions.dart';
import 'relationships.dart';

/// Typed error taxonomy (Phase 26). Misconceptions were one broad bucket;
/// real teachers respond differently to a false friend than to a careless
/// slip. Pure, deterministic classification from data already captured —
/// nothing inferred that was not measured.

enum ErrorCategory {
  grammar,
  vocabulary,
  pronunciation,
  englishTransfer,
  listening,
  confidence,
  memoryLapse,
  wordOrder,
  articleGender,
  register,
  falseFriend,
  verbTense,
  agreement,
  aspect,
  preposition,
  careless,
}

/// How the teacher should respond to a category of error.
class ErrorTeachingStrategy {
  const ErrorTeachingStrategy({required this.category, required this.approach});

  final ErrorCategory category;
  final String approach;
}

/// Classifies a tracked misconception from its real captured fields (relation
/// type, interference source, concept id) — never from guesswork.
ErrorCategory classifyMisconception(Misconception m) {
  if (m.relationType == LanguageRelationType.falseFriend) {
    return ErrorCategory.falseFriend;
  }
  if (m.relationType == LanguageRelationType.interferesWith ||
      m.interferenceSource.startsWith('en:')) {
    return ErrorCategory.englishTransfer;
  }
  final id = m.conceptId;
  if (id.contains(':vocabulary:')) return ErrorCategory.vocabulary;
  if (id.contains('tense') || id.contains('imperfect') || id.contains('past')) {
    return ErrorCategory.verbTense;
  }
  if (id.contains('gender') || id.contains('article')) {
    return ErrorCategory.articleGender;
  }
  if (id.contains('preposition') || id.contains(':por') || id.contains(':para')) {
    return ErrorCategory.preposition;
  }
  if (id.contains(':grammar:')) return ErrorCategory.grammar;
  return ErrorCategory.grammar;
}

/// Classifies a one-off wrong answer from measured attempt facts. A concept
/// answered correctly many times before → memory lapse or careless, split by
/// response speed. Low speaking confidence + spoken mode → confidence.
ErrorCategory classifyAttempt({
  required bool previouslyMastered,
  required bool fastResponse,
  bool spoken = false,
  double? speakingConfidence,
}) {
  if (spoken && (speakingConfidence ?? 1) < 0.4) {
    return ErrorCategory.confidence;
  }
  if (previouslyMastered) {
    return fastResponse ? ErrorCategory.careless : ErrorCategory.memoryLapse;
  }
  return ErrorCategory.grammar;
}

/// The per-category teaching response — each category triggers a different
/// strategy, exactly as a human teacher would.
ErrorTeachingStrategy strategyFor(ErrorCategory category) {
  final approach = switch (category) {
    ErrorCategory.falseFriend =>
      'Contrast the pair explicitly — the lookalike is the trap.',
    ErrorCategory.englishTransfer =>
      'Name the English pattern interfering, then drill the Spanish family.',
    ErrorCategory.verbTense =>
      'Timeline the tenses side by side; connect to a story already read.',
    ErrorCategory.articleGender =>
      'Teach the noun with its article as one word, never separately.',
    ErrorCategory.preposition =>
      'Teach the mental model (por = through, para = toward), not a rule list.',
    ErrorCategory.wordOrder =>
      'Rebuild the sentence together, one moved piece at a time.',
    ErrorCategory.agreement =>
      'Highlight the agreeing pair and practice matching them.',
    ErrorCategory.aspect =>
      'Contrast ongoing vs completed with two versions of one sentence.',
    ErrorCategory.memoryLapse =>
      'No re-teaching — a quick spaced review restores it.',
    ErrorCategory.careless =>
      'Ignore it — mention nothing unless it repeats.',
    ErrorCategory.confidence =>
      'Lower the stakes: easier prompt, praise the attempt, retry.',
    ErrorCategory.listening =>
      'Replay slower, then at natural speed — ear before rule.',
    ErrorCategory.pronunciation =>
      'Isolate the sound in words the learner knows, then rebuild.',
    ErrorCategory.register =>
      'Show the formal and informal versions side by side in context.',
    ErrorCategory.vocabulary =>
      'Connect the word to its semantic family, never alone.',
    ErrorCategory.grammar =>
      'Guide discovery from a known example before explaining.',
  };
  return ErrorTeachingStrategy(category: category, approach: approach);
}
