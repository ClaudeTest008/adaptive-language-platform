import 'connections.dart';
import 'entities.dart';
import 'misconceptions.dart';
import 'teacher_brain.dart';

/// Curiosity Engine + Connection Moments (Phase 19). A real teacher notices
/// opportunities and mentions them naturally — never spam. These are short,
/// deterministic observations derived from the learner's real state; each only
/// appears when its condition is genuinely met, and the list is capped.

/// A spontaneous teaching observation ("You're almost there…").
class CuriosityNote {
  const CuriosityNote(
    this.text, {
    this.priority = 5,
    this.conceptIds = const [],
  });

  final String text;
  final int priority;
  final List<String> conceptIds;
}

/// A tiny "this connects to…" aside the teacher can drop mid-lesson.
class ConnectionMoment {
  const ConnectionMoment(this.text, {this.conceptIds = const []});

  final String text;
  final List<String> conceptIds;
}

/// Discovers a few genuine curiosities from the learner's facts, connections
/// and misconceptions. Capped and priority-sorted so the teacher speaks up only
/// when there is something real to say.
List<CuriosityNote> discoverCuriosities({
  required LearnerFacts facts,
  required ConnectionGraph connections,
  List<Misconception> misconceptions = const [],
  bool storiesAvailable = false,
  int maxNotes = 3,
}) {
  final notes = <CuriosityNote>[];

  // Repeated pattern — the strongest signal to act on.
  for (final m in misconceptions) {
    if (m.occurrences >= 3) {
      notes.add(
        CuriosityNote(
          "This is the ${m.occurrences}th time this pattern has tripped you "
          "up — good news, that means it's exactly what we should fix next.",
          priority: 1,
          conceptIds: [m.conceptId],
        ),
      );
      break;
    }
  }

  // Avoiding speaking.
  final speaking = facts.skills[LanguageSkill.speaking]?.level;
  if (speaking != null && speaking < 0.3) {
    notes.add(
      const CuriosityNote(
        "I've noticed you're holding back on speaking — let's ease into it "
        'with something short.',
        priority: 2,
      ),
    );
  }

  // Ready to start reading.
  if (storiesAvailable && facts.vocabulary.mastery >= 0.4) {
    notes.add(
      const CuriosityNote(
        "You've learned enough vocabulary to begin reading short stories.",
        priority: 3,
      ),
    );
  }

  // Almost mastered a skill.
  for (final s in facts.skills.values) {
    if (s.level >= 0.7 && s.level < 0.85) {
      notes.add(
        CuriosityNote(
          "You've almost mastered ${s.skill.name} — one more push and it's "
          'yours.',
          priority: 4,
        ),
      );
      break;
    }
  }

  notes.sort((a, b) => a.priority.compareTo(b.priority));
  return notes.take(maxNotes).toList();
}

/// Builds short "this connects to…" moments from strong connections the learner
/// already holds — architecture the tutor and reader use to weave references to
/// earlier learning into a lesson.
List<ConnectionMoment> buildConnectionMoments(
  ConnectionGraph graph, {
  int maxMoments = 3,
}) {
  final moments = <ConnectionMoment>[];
  for (final e in graph.strongConnections) {
    final known = graph.nodes[e.fromId];
    final other = graph.nodes[e.toId];
    if (known == null || other == null) continue;
    moments.add(
      ConnectionMoment(
        'This works just like ${known.name}, which you already know.',
        conceptIds: [e.fromId, e.toId],
      ),
    );
    if (moments.length >= maxMoments) break;
  }
  return moments;
}
