/// Daily lesson PREVIEW (ADR-0016). Deterministic, time-budgeted blocks
/// assembled from per-skill mastery + misconceptions.
///
/// ponytail: stopgap showcase for the Phase 2 UI — the full Daily Lesson
/// Engine (review schedule, goals, past performance) is Phase 4 and
/// replaces this file's heuristics.
library;

import 'entities.dart';
import 'misconceptions.dart';
import 'relationships.dart';
import 'signals.dart';

enum LessonBlockKind { repair, review, practice, conversation }

class LessonBlock {
  const LessonBlock({
    required this.kind,
    required this.title,
    required this.minutes,
    this.skill,
    this.conceptIds = const [],
  });

  final LessonBlockKind kind;
  final String title;
  final int minutes;
  final LanguageSkill? skill;
  final List<String> conceptIds;
}

/// Today's plan. Misconception repair always leads when misconceptions
/// exist — systematic errors compound until taught away.
List<LessonBlock> previewDailyLesson({
  required Map<String, double> conceptMastery,
  required LanguageKnowledgeGraph graph,
  required MisconceptionLog misconceptions,
  int availableMinutes = 25,
}) {
  final blocks = <LessonBlock>[];
  var remaining = availableMinutes;

  // Worst misconceptions, one per concept (a concept can carry several
  // log entries — interference relation + transfer trap).
  final worst = <Misconception>[];
  for (final m in misconceptions.all) {
    if (worst.length == 2) break;
    if (!worst.any((w) => w.conceptId == m.conceptId)) worst.add(m);
  }
  if (worst.isNotEmpty) {
    var minutes = (availableMinutes * 0.4).round();
    if (minutes < 5) minutes = 5;
    if (minutes > remaining) minutes = remaining;
    final conceptIds = <String>{
      for (final m in worst) ...[m.conceptId, ...m.relatedConceptIds],
    };
    blocks.add(
      LessonBlock(
        kind: LessonBlockKind.repair,
        title:
            'Repair: ${worst.map((m) => graph[m.conceptId]?.name ?? m.conceptId).join(", ")}',
        minutes: minutes,
        skill: graph[worst.first.conceptId]?.skill,
        conceptIds: conceptIds.toList(),
      ),
    );
    remaining -= minutes;
  }

  final ranked = weakestSkills(conceptMastery, graph);
  for (final skill in ranked.take(2)) {
    if (remaining <= 0) break;
    final minutes = remaining >= 10 ? 10 : remaining;
    final concepts = [
      for (final e in conceptMastery.entries)
        if (graph[e.key]?.skill == skill && e.value < 0.7) e.key,
    ];
    blocks.add(
      LessonBlock(
        kind: LessonBlockKind.review,
        title: 'Strengthen ${skill.name}',
        minutes: minutes,
        skill: skill,
        conceptIds: concepts,
      ),
    );
    remaining -= minutes;
  }

  if (remaining > 0) {
    final scenarios = [
      for (final n in graph.nodes.values)
        if (n.tier == LanguageTier.conversation) n.conceptId,
    ];
    blocks.add(
      LessonBlock(
        kind: scenarios.isEmpty
            ? LessonBlockKind.practice
            : LessonBlockKind.conversation,
        title: scenarios.isEmpty ? 'Free practice' : 'Conversation practice',
        minutes: remaining,
        skill: LanguageSkill.conversation,
        conceptIds: scenarios,
      ),
    );
  }
  return blocks;
}
