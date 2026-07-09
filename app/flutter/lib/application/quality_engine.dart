/// Content Quality Engine (ADR-0011): deterministic, explainable quality
/// scoring — no AI required. AI review (AiContentReviewer) supplements
/// these heuristics when a provider is bound; it never replaces them.
library;

import '../domain/models.dart';

/// Token-set Jaccard similarity, 0..1 — duplicate probability proxy.
double textSimilarity(String a, String b) {
  Set<String> tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toSet();
  final ta = tokens(a), tb = tokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;
  return ta.intersection(tb).length / ta.union(tb).length;
}

/// Scores one question. [existing] enables near-duplicate detection
/// (exact duplicates are already blocked by the import pipeline).
QualityReport assessQuality(Question q, {List<Question> existing = const []}) {
  final issues = <String>[];
  var score = 1.0;
  void penalize(double amount, String issue) {
    score -= amount;
    issues.add(issue);
  }

  // Clarity: question length bounds.
  final words = q.text.trim().split(RegExp(r'\s+'));
  if (words.length < 4) {
    penalize(0.25, 'Question very short — may lack context.');
  }
  if (words.length > 60) {
    penalize(0.15, 'Question very long — consider splitting.');
  }
  if (!q.text.trim().endsWith('?') && !q.text.trim().endsWith(':')) {
    penalize(0.05, 'Question does not read as a prompt (no "?" or ":").');
  }

  // Ambiguity signals.
  final lower = q.text.toLowerCase();
  if (RegExp(r'\bnot\b|\bnever\b|\bexcept\b').hasMatch(lower) &&
      !lower.contains('cannot')) {
    penalize(
      0.1,
      'Negative phrasing ("not"/"except") — frequent ambiguity source.',
    );
  }
  final answerTexts = q.answers.map((a) => a.toLowerCase().trim()).toList();
  if (answerTexts.any(
    (a) => a.contains('all of the above') || a.contains('none of the above'),
  )) {
    penalize(0.15, '"All/none of the above" distractor — weak learning value.');
  }

  // Distractor quality.
  if (answerTexts.toSet().length != answerTexts.length) {
    penalize(0.3, 'Duplicate answer options.');
  }
  final lengths = q.answers.map((a) => a.length).toList()..sort();
  if (lengths.length >= 2 && lengths.last > 3 * lengths.first + 10) {
    penalize(
      0.1,
      'Answer lengths very unbalanced — correct answer may be guessable.',
    );
  }
  if (q.answers.length < 3) {
    penalize(0.1, 'Only ${q.answers.length} options — weak discrimination.');
  }

  // Explanation quality.
  final expl = q.explanation.trim();
  if (expl.split(RegExp(r'\s+')).length < 5) {
    penalize(0.2, 'Explanation too short to teach the underlying rule.');
  }
  if (textSimilarity(expl, q.answers[q.correctIndex]) > 0.8) {
    penalize(0.1, 'Explanation merely restates the correct answer.');
  }

  // Near-duplicate probability against existing content.
  var maxSim = 0.0;
  String? similarTo;
  for (final e in existing) {
    if (e.id == q.id || e.status == ContentStatus.archived) continue;
    final sim = textSimilarity(q.text, e.text);
    if (sim > maxSim) {
      maxSim = sim;
      similarTo = e.id;
    }
  }
  if (maxSim >= 0.7) {
    penalize(
      0.3,
      'Likely duplicate of $similarTo '
      '(${(maxSim * 100).round()}% similar).',
    );
  } else if (maxSim >= 0.5) {
    penalize(
      0.1,
      'Overlaps with $similarTo '
      '(${(maxSim * 100).round()}% similar).',
    );
  }

  return QualityReport(score: score.clamp(0.0, 1.0), issues: issues);
}
