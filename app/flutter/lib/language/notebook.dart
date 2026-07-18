import 'entities.dart';
import 'misconceptions.dart';

/// The Teacher's Notebook — the app's persistent memory of the learner,
/// written in a teacher's voice (Phase 17). Pure and deterministic: given the
/// learner's live metrics (and, optionally, a snapshot from a previous
/// session for trends), it produces plain-language teaching observations.
///
/// Every note is grounded in real data — nothing is fabricated. When a signal
/// has not been measured yet, the corresponding note is simply omitted rather
/// than invented. An AI observer can later enrich this, but the offline engine
/// already makes the notebook meaningful without any model.

/// What a note is about — drives the icon and grouping in the UI.
enum ObservationCategory {
  grammar,
  vocabulary,
  listening,
  speaking,
  pronunciation,
  reading,
  conversation,
  trend,
  focus,
  encouragement,
  plan,
}

/// An observation reflects the present; a plan looks ahead to next lessons.
enum ObservationKind { observation, plan }

/// One line in the notebook.
class TeacherObservation {
  const TeacherObservation(
    this.text, {
    required this.category,
    this.kind = ObservationKind.observation,
    this.priority = 5,
  });

  final String text;
  final ObservationCategory category;
  final ObservationKind kind;

  /// Lower shows first; used to rank when trimming to [maxNotes].
  final int priority;
}

/// The rendered notebook: ranked observations plus the current CEFR estimate.
class TeacherNotebook {
  const TeacherNotebook({
    required this.observations,
    required this.cefrEstimate,
  });

  final List<TeacherObservation> observations;

  /// A rough working level, e.g. 'A1' or 'A2' — an estimate, shown as such.
  final String cefrEstimate;
}

/// A persisted metrics snapshot. Only the numbers needed to render notes and
/// compute trends are stored — the prose is always regenerated live so it
/// never goes stale.
class NotebookSnapshot {
  const NotebookSnapshot({
    required this.day,
    required this.mastery,
    required this.accuracy,
    required this.misconceptionTotal,
  });

  /// ISO calendar day (yyyy-mm-dd) the snapshot was taken.
  final String day;
  final Map<LanguageSkill, double> mastery;
  final double accuracy;
  final int misconceptionTotal;

  Map<String, dynamic> toJson() => {
    'day': day,
    'accuracy': accuracy,
    'misconceptionTotal': misconceptionTotal,
    'mastery': {for (final e in mastery.entries) e.key.name: e.value},
  };

  factory NotebookSnapshot.fromJson(Map<String, dynamic> json) {
    final rawMastery = (json['mastery'] as Map?) ?? const {};
    return NotebookSnapshot(
      day: json['day'] as String,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      misconceptionTotal: (json['misconceptionTotal'] as num?)?.toInt() ?? 0,
      mastery: {
        for (final e in rawMastery.entries)
          if (LanguageSkill.values.any((s) => s.name == e.key))
            LanguageSkill.values.byName(e.key as String):
                (e.value as num).toDouble(),
      },
    );
  }
}

double _avg(Iterable<double> xs) {
  final list = xs.toList();
  if (list.isEmpty) return 0;
  return list.reduce((a, b) => a + b) / list.length;
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Estimates a working CEFR band from the base level and average mastery.
/// Deliberately coarse — it is presented to the learner as "around X".
String estimateCefr({required String baseLevel, required double avgMastery}) {
  final base = baseLevel.toUpperCase();
  if (avgMastery >= 0.85) return _nextBand(base);
  if (avgMastery >= 0.6) return '$base+';
  return base;
}

String _nextBand(String base) {
  const order = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final i = order.indexOf(base);
  return (i >= 0 && i < order.length - 1) ? order[i + 1] : base;
}

/// Builds the notebook from live learner metrics. All inputs are already
/// summarized so the engine stays free of provider/store dependencies.
TeacherNotebook buildTeacherNotebook({
  required Map<LanguageSkill, double> mastery,
  required List<Misconception> misconceptions,
  required double accuracy,
  required int totalAnswered,
  required String baseLevel,
  Map<String, String> conceptNames = const {},
  double? pronunciationConfidence,
  double? listeningRecognition,
  double? conversationAbility,
  NotebookSnapshot? previous,
  String? nextConceptName,
  int maxNotes = 7,
}) {
  final avgMastery = _avg(mastery.values);
  final cefr = estimateCefr(baseLevel: baseLevel, avgMastery: avgMastery);

  // Brand-new learner: be honest, don't invent a history.
  if (totalAnswered == 0 && misconceptions.isEmpty) {
    return TeacherNotebook(
      cefrEstimate: cefr,
      observations: const [
        TeacherObservation(
          "We're just getting started — I'll fill this page in as we work "
          'together.',
          category: ObservationCategory.encouragement,
          priority: 1,
        ),
      ],
    );
  }

  final notes = <TeacherObservation>[];

  // 1 · Recurring grammar mistakes — the teacher's top concern.
  final ranked = [...misconceptions]
    ..sort((a, b) => b.occurrences.compareTo(a.occurrences));
  for (final m in ranked.take(2)) {
    final name = conceptNames[m.conceptId] ?? m.pattern;
    notes.add(
      TeacherObservation(
        'You keep slipping on $name (seen ${m.occurrences}×).',
        category: ObservationCategory.grammar,
        priority: 1,
      ),
    );
  }

  // 2 · Vocabulary progress against the level being learned.
  final vocab = mastery[LanguageSkill.vocabulary];
  if (vocab != null && vocab > 0) {
    notes.add(
      TeacherObservation(
        'You have mastered ${(vocab * 100).round()}% of '
        '${baseLevel.toUpperCase()} vocabulary.',
        category: ObservationCategory.vocabulary,
        priority: 4,
      ),
    );
  }

  // 3 · Strongest and weakest skills (only among skills with real data).
  final active = mastery.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (active.length >= 2) {
    final strong = active.first;
    final weak = active.last;
    if (strong.key != LanguageSkill.vocabulary) {
      notes.add(
        TeacherObservation(
          'Your ${strong.key.name} is your strongest area right now '
          '(${(strong.value * 100).round()}%).',
          category: ObservationCategory.encouragement,
          priority: 4,
        ),
      );
    }
    notes.add(
      TeacherObservation(
        "Let's give ${weak.key.name} more attention — it is lagging behind.",
        category: ObservationCategory.focus,
        priority: 2,
      ),
    );
  }

  // 4 · Listening vs speaking balance — a recurring teaching theme.
  final listening = mastery[LanguageSkill.listening];
  final speaking = mastery[LanguageSkill.speaking];
  if (listening != null && speaking != null && listening > 0 && speaking > 0) {
    if ((listening - speaking).abs() > 0.1) {
      notes.add(
        listening > speaking
            ? const TeacherObservation(
                'Listening is ahead of speaking — time to get you talking '
                'more.',
                category: ObservationCategory.speaking,
                priority: 3,
              )
            : const TeacherObservation(
                'Your speaking is outpacing your listening — more audio '
                'input next.',
                category: ObservationCategory.listening,
                priority: 3,
              ),
      );
    }
  }

  // 5 · Pronunciation, once we have measured it.
  if (pronunciationConfidence != null) {
    notes.add(
      pronunciationConfidence >= 0.7
          ? TeacherObservation(
              'Your pronunciation is coming along nicely '
              '(${(pronunciationConfidence * 100).round()}%).',
              category: ObservationCategory.pronunciation,
              priority: 3,
            )
          : const TeacherObservation(
              'Pronunciation needs steady drilling — short daily bursts help '
              'most.',
              category: ObservationCategory.pronunciation,
              priority: 3,
            ),
    );
  }

  // 6 · Trend vs the last session we recorded.
  if (previous != null) {
    final delta = avgMastery - _avg(previous.mastery.values);
    if (delta > 0.03) {
      notes.add(
        const TeacherObservation(
          'Your overall mastery is up since we last worked together — keep '
          'this rhythm.',
          category: ObservationCategory.trend,
          priority: 2,
        ),
      );
    } else if (delta < -0.03) {
      notes.add(
        const TeacherObservation(
          "You've slipped a little since last time — we'll review before "
          'moving on.',
          category: ObservationCategory.trend,
          priority: 2,
        ),
      );
    } else {
      notes.add(
        const TeacherObservation(
          "You're holding steady — consistent practice is paying off.",
          category: ObservationCategory.trend,
          priority: 5,
        ),
      );
    }
  }

  // 7 · The plan — what we do next.
  if (nextConceptName != null && nextConceptName.isNotEmpty) {
    notes.add(
      TeacherObservation(
        'Next up: ${_titleCase(nextConceptName)}.',
        category: ObservationCategory.plan,
        kind: ObservationKind.plan,
        priority: 6,
      ),
    );
  }

  notes.sort((a, b) => a.priority.compareTo(b.priority));
  return TeacherNotebook(
    cefrEstimate: cefr,
    observations: notes.take(maxNotes).toList(),
  );
}
