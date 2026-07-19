import 'lesson_outcomes.dart';
import 'roleplay_engine.dart';
import 'teacher_brain.dart';
import 'teaching_style.dart';

/// Persistent Teacher Memory (Phase 31). Pure model + repository seam. It
/// stores only MEASURED teaching history — completed lessons and the last
/// roleplay position — so the teacher genuinely remembers across restarts. It
/// holds no learner state of its own; the Teacher Brain still derives the
/// learner model, now with persisted lesson history feeding it.

/// A finished lesson, persisted. Compact and measured — the fields the memory
/// engine and the brain need, nothing more.
class CompletedLesson {
  const CompletedLesson({
    required this.day,
    required this.objective,
    this.speakingScore,
    this.readingKnownRatio,
    this.conceptsMastered = const [],
    this.conceptsStruggled = const [],
    this.connectionsReinforced = const [],
    this.eventKinds = const [],
    this.reflectionImproved = const [],
    this.reflectionNext,
    this.roleplayTitle,
    this.roleplayCompleted,
  });

  final String day;
  final String objective;
  final double? speakingScore;
  final double? readingKnownRatio;
  final List<String> conceptsMastered;
  final List<String> conceptsStruggled;
  final List<String> connectionsReinforced;
  final List<String> eventKinds;
  final List<String> reflectionImproved;
  final String? reflectionNext;
  final String? roleplayTitle;
  final bool? roleplayCompleted;

  /// Overall measured score of the lesson (speaking or reading).
  double get score => speakingScore ?? readingKnownRatio ?? 0;

  /// Feeds the brain's compact lesson history (cross-restart continuity).
  LessonOutcome toOutcome() => LessonOutcome(
    day: day,
    objective: objective,
    score: score,
    confidence: score,
    mistakes: conceptsStruggled,
    grammarGained: conceptsMastered,
    nextRecommendation: reflectionNext,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'objective': objective,
    'speakingScore': speakingScore,
    'readingKnownRatio': readingKnownRatio,
    'conceptsMastered': conceptsMastered,
    'conceptsStruggled': conceptsStruggled,
    'connectionsReinforced': connectionsReinforced,
    'eventKinds': eventKinds,
    'reflectionImproved': reflectionImproved,
    'reflectionNext': reflectionNext,
    'roleplayTitle': roleplayTitle,
    'roleplayCompleted': roleplayCompleted,
  };

  factory CompletedLesson.fromJson(Map<String, dynamic> j) => CompletedLesson(
    day: j['day'] as String,
    objective: j['objective'] as String,
    speakingScore: (j['speakingScore'] as num?)?.toDouble(),
    readingKnownRatio: (j['readingKnownRatio'] as num?)?.toDouble(),
    conceptsMastered:
        [...(j['conceptsMastered'] as List? ?? const []).cast<String>()],
    conceptsStruggled:
        [...(j['conceptsStruggled'] as List? ?? const []).cast<String>()],
    connectionsReinforced:
        [...(j['connectionsReinforced'] as List? ?? const []).cast<String>()],
    eventKinds: [...(j['eventKinds'] as List? ?? const []).cast<String>()],
    reflectionImproved:
        [...(j['reflectionImproved'] as List? ?? const []).cast<String>()],
    reflectionNext: j['reflectionNext'] as String?,
    roleplayTitle: j['roleplayTitle'] as String?,
    roleplayCompleted: j['roleplayCompleted'] as bool?,
  );
}

/// Builds a persistable lesson from the Phase 30 engines' output.
CompletedLesson completedFromResult(
  LessonResult result, {
  TeacherReflection? reflection,
  RoleplayCompletion? roleplay,
}) => CompletedLesson(
  day: result.day,
  objective: result.objective,
  speakingScore: result.speakingScore,
  readingKnownRatio: result.readingKnownRatio,
  conceptsMastered: result.conceptsMastered,
  conceptsStruggled: result.conceptsStruggled,
  connectionsReinforced: result.connectionsReinforced,
  eventKinds: [for (final e in result.events) e.kind.name],
  reflectionImproved: reflection?.whatImproved ?? const [],
  reflectionNext: reflection?.nextAdjustment,
  roleplayTitle: roleplay?.scenario.title,
  roleplayCompleted: roleplay?.success,
);

/// The last roleplay position, persisted so an interrupted scene resumes.
class RoleplayMemory {
  const RoleplayMemory({
    required this.title,
    required this.kind,
    required this.stageIndex,
    required this.done,
    required this.day,
  });

  final String title;
  final RoleplayKind kind;
  final int stageIndex;
  final bool done;
  final String day;

  Map<String, dynamic> toJson() => {
    'title': title,
    'kind': kind.name,
    'stageIndex': stageIndex,
    'done': done,
    'day': day,
  };

  factory RoleplayMemory.fromJson(Map<String, dynamic> j) => RoleplayMemory(
    title: j['title'] as String,
    kind: RoleplayKind.values.byName(j['kind'] as String),
    stageIndex: (j['stageIndex'] as num).toInt(),
    done: j['done'] as bool,
    day: j['day'] as String,
  );
}

/// Persistence seam for teacher memory. In-memory default; a prefs-backed
/// implementation lives in infrastructure.
abstract class TeacherMemoryRepository {
  Future<List<CompletedLesson>> loadLessons();
  Future<void> appendLesson(CompletedLesson lesson);
  Future<RoleplayMemory?> loadRoleplay();
  Future<void> saveRoleplay(RoleplayMemory? roleplay);
}

/// Keeps at most this many completed lessons.
const int teacherMemoryCap = 200;

/// Merges a lesson into history: one entry per (day, objective), capped.
List<CompletedLesson> mergeLesson(
  List<CompletedLesson> history,
  CompletedLesson lesson,
) {
  final next = [
    for (final l in history)
      if (!(l.day == lesson.day && l.objective == lesson.objective)) l,
    lesson,
  ];
  return next.length > teacherMemoryCap
      ? next.sublist(next.length - teacherMemoryCap)
      : next;
}

class InMemoryTeacherMemoryRepository implements TeacherMemoryRepository {
  final List<CompletedLesson> _lessons = [];
  RoleplayMemory? _roleplay;

  @override
  Future<List<CompletedLesson>> loadLessons() async =>
      List.unmodifiable(_lessons);

  @override
  Future<void> appendLesson(CompletedLesson lesson) async {
    final merged = mergeLesson(_lessons, lesson);
    _lessons
      ..clear()
      ..addAll(merged);
  }

  @override
  Future<RoleplayMemory?> loadRoleplay() async => _roleplay;

  @override
  Future<void> saveRoleplay(RoleplayMemory? roleplay) async =>
      _roleplay = roleplay;
}
