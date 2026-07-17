/// Daily Personalized Lesson Engine (ADR-0022). Pure Dart.
///
/// Builds today's time-budgeted plan from the whole learner picture:
/// misconception repair (first), spaced-repetition reviews, weak skills,
/// pronunciation confidence, story reading, and conversation — shaped by
/// Learning DNA traits, recent accuracy and available time. Deterministic
/// given its inputs; the core engine is read, never modified.
library;

import 'entities.dart';
import 'misconceptions.dart';
import 'relationships.dart';
import 'signals.dart';
import 'story.dart';

enum LessonBlockKind {
  repair,
  review,
  grammar,
  vocabulary,
  pronunciation,
  story,
  conversation,
  practice,
}

/// What tapping a block launches.
enum LessonActivity { practice, speaking, story, tutor }

class LessonBlock {
  const LessonBlock({
    required this.kind,
    required this.activity,
    required this.title,
    required this.reason,
    required this.minutes,
    this.skill,
    this.conceptIds = const [],
    this.storyId,
  });

  final LessonBlockKind kind;
  final LessonActivity activity;
  final String title;

  /// Why this block is here today — the personalization made visible.
  final String reason;
  final int minutes;
  final LanguageSkill? skill;
  final List<String> conceptIds;
  final String? storyId;
}

/// A candidate block before minutes are allocated.
class _Candidate {
  _Candidate(this.block, this.weight);
  final LessonBlock block;
  double weight;
}

/// Builds today's plan. [dueConceptIds] are the spaced-repetition concepts
/// due now (computed from core ConceptStats by the caller). [traits] are
/// Learning DNA trait names; [recentAccuracy] is 0..1 past performance.
List<LessonBlock> buildDailyLesson({
  required Map<String, double> conceptMastery,
  required LanguageKnowledgeGraph graph,
  required MisconceptionLog misconceptions,
  required LanguageSignalsStore signals,
  Set<String> dueConceptIds = const {},
  List<String> traits = const [],
  List<Story> stories = const [],
  double recentAccuracy = 1.0,
  int availableMinutes = 25,
}) {
  final has = traits.toSet();
  final candidates = <_Candidate>[];

  // 1. Misconception repair — always first, always heaviest when present.
  final worst = <Misconception>[];
  for (final m in misconceptions.all) {
    if (worst.length == 2) break;
    if (!worst.any((w) => w.conceptId == m.conceptId)) worst.add(m);
  }
  if (worst.isNotEmpty) {
    final names =
        worst.map((m) => graph[m.conceptId]?.name ?? m.conceptId).join(', ');
    final occ = worst.first.occurrences;
    candidates.add(_Candidate(
      LessonBlock(
        kind: LessonBlockKind.repair,
        activity: LessonActivity.practice,
        title: 'Repair: $names',
        reason: has.contains('repeatsMistakes')
            ? "You keep repeating this ($occ×) — we clear it first."
            : "Seen $occ× — systematic slips compound, so repair leads.",
        minutes: 0,
        skill: graph[worst.first.conceptId]?.skill,
        conceptIds: {
          for (final m in worst) ...[m.conceptId, ...m.relatedConceptIds],
        }.toList(),
      ),
      has.contains('repeatsMistakes') ? 4.5 : 3.5,
    ));
  }

  // 2. Spaced-repetition reviews — concepts the schedule says are due.
  final due = [
    for (final id in dueConceptIds)
      if (graph[id] != null) id,
  ];
  if (due.isNotEmpty) {
    candidates.add(_Candidate(
      LessonBlock(
        kind: LessonBlockKind.review,
        activity: LessonActivity.practice,
        title: '${due.length} due for review',
        reason: 'Spaced repetition: these are due today before they fade.',
        minutes: 0,
        conceptIds: due,
      ),
      has.contains('benefitsFromRepetition') ? 3.0 : 2.2,
    ));
  }

  // 3. Weakest skill (grammar/vocab/…) below competence.
  final ranked = weakestSkills(conceptMastery, graph);
  for (final skill in ranked.take(2)) {
    final skillMean = _skillMean(conceptMastery, graph, skill);
    if (skillMean >= 0.7) continue;
    final concepts = [
      for (final e in conceptMastery.entries)
        if (graph[e.key]?.skill == skill && e.value < 0.7) e.key,
    ];
    if (concepts.isEmpty) continue;
    candidates.add(_Candidate(
      LessonBlock(
        kind: _skillKind(skill),
        activity: LessonActivity.practice,
        title: 'Strengthen ${_cap(skill.name)}',
        reason:
            '${_cap(skill.name)} is a weak spot (${(skillMean * 100).round()}%).',
        minutes: 0,
        skill: skill,
        conceptIds: concepts,
      ),
      2.0,
    ));
  }

  // 4. Pronunciation — concepts with low/absent spoken confidence.
  final speakTargets = [
    for (final e in conceptMastery.entries)
      if (graph[e.key] != null &&
          (signals[e.key].pronunciationConfidence ?? 0) < 0.5)
        e.key,
  ];
  if (speakTargets.isNotEmpty) {
    candidates.add(_Candidate(
      LessonBlock(
        kind: LessonBlockKind.pronunciation,
        activity: LessonActivity.speaking,
        title: 'Pronunciation drills',
        reason: 'Say it aloud — production locks in what recognition can\'t.',
        minutes: 0,
        skill: LanguageSkill.pronunciation,
        conceptIds: speakTargets.take(6).toList(),
      ),
      has.contains('fastResponder') ? 1.6 : 1.3,
    ));
  }

  // 5. Story reading — the story that best reuses today's weak concepts.
  final story = _bestStory(stories, {
    for (final c in candidates) ...c.block.conceptIds,
  });
  if (story != null) {
    candidates.add(_Candidate(
      LessonBlock(
        kind: LessonBlockKind.story,
        activity: LessonActivity.story,
        title: 'Read: ${story.title}',
        reason: 'A short story that reuses today\'s words in context.',
        minutes: 0,
        storyId: story.id,
        conceptIds: story.conceptIds.toList(),
      ),
      1.4,
    ));
  }

  // 6. Conversation — spend the tail talking to the tutor.
  final scenarios = [
    for (final n in graph.nodes.values)
      if (n.tier == LanguageTier.conversation) n.conceptId,
  ];
  candidates.add(_Candidate(
    LessonBlock(
      kind: scenarios.isEmpty
          ? LessonBlockKind.practice
          : LessonBlockKind.conversation,
      activity: LessonActivity.tutor,
      title: scenarios.isEmpty ? 'Free practice' : 'Conversation with your tutor',
      reason: recentAccuracy >= 0.7
          ? 'You\'re on a roll — put it to use in real dialogue.'
          : 'Low-pressure conversation to consolidate the session.',
      minutes: 0,
      skill: LanguageSkill.conversation,
      conceptIds: scenarios,
    ),
    1.0,
  ));

  return _allocate(candidates, availableMinutes, has);
}

/// Distributes [availableMinutes] across candidates by weight (repair
/// first), each block ≥5 min; drops the lowest-priority blocks that don't
/// fit. Minutes always sum to [availableMinutes] when any block fits.
List<LessonBlock> _allocate(
  List<_Candidate> candidates,
  int availableMinutes,
  Set<String> traits,
) {
  if (candidates.isEmpty || availableMinutes < 5) return const [];
  // Learners who struggle under time pressure get fewer, longer blocks.
  final maxBlocks = traits.contains('strugglesUnderTimePressure')
      ? 3
      : availableMinutes ~/ 5;
  final kept = candidates.take(maxBlocks.clamp(1, candidates.length)).toList();

  // Drop trailing blocks until every kept block can get ≥5 min.
  while (kept.length > 1 && kept.length * 5 > availableMinutes) {
    kept.removeLast();
  }

  final totalWeight = kept.fold(0.0, (s, c) => s + c.weight);
  final minutes = <int>[];
  var assigned = 0;
  for (final c in kept) {
    final m = ((c.weight / totalWeight) * availableMinutes).round().clamp(5, availableMinutes);
    minutes.add(m);
    assigned += m;
  }
  // Reconcile rounding drift onto the first (repair) block.
  minutes[0] += availableMinutes - assigned;
  if (minutes[0] < 5) minutes[0] = 5;

  return [
    for (var i = 0; i < kept.length; i++)
      LessonBlock(
        kind: kept[i].block.kind,
        activity: kept[i].block.activity,
        title: kept[i].block.title,
        reason: kept[i].block.reason,
        minutes: minutes[i],
        skill: kept[i].block.skill,
        conceptIds: kept[i].block.conceptIds,
        storyId: kept[i].block.storyId,
      ),
  ];
}

double _skillMean(
  Map<String, double> mastery,
  LanguageKnowledgeGraph graph,
  LanguageSkill skill,
) {
  final vals = [
    for (final e in mastery.entries)
      if (graph[e.key]?.skill == skill) e.value,
  ];
  if (vals.isEmpty) return 1.0;
  return vals.reduce((a, b) => a + b) / vals.length;
}

LessonBlockKind _skillKind(LanguageSkill skill) => switch (skill) {
  LanguageSkill.grammar => LessonBlockKind.grammar,
  LanguageSkill.vocabulary => LessonBlockKind.vocabulary,
  _ => LessonBlockKind.review,
};

/// Story with the most concept overlap with today's focus; falls back to
/// the first (easiest) story.
Story? _bestStory(List<Story> stories, Set<String> focus) {
  if (stories.isEmpty) return null;
  Story? best;
  var bestOverlap = -1;
  for (final s in stories) {
    final overlap = s.conceptIds.where(focus.contains).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = s;
    }
  }
  return best ?? stories.first;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
