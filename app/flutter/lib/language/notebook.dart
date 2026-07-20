import 'connections.dart';
import 'entities.dart';
import 'misconceptions.dart';

/// Observation layer of the Teacher Brain (Phase 17). Pure and deterministic:
/// given the learner's live FACTS (and, optionally, a snapshot from a previous
/// session for trends), it produces plain-language teaching OBSERVATIONS, each
/// carrying the evidence that justifies it so the UI can explain every note.
///
/// Facts remain authoritative; observations are always generated from them and
/// never fabricated — a note only appears when its underlying signal has been
/// measured. This is the offline reasoning; a premium engine can replace it
/// behind the `ReasoningEngine` interface without changing the model or UI.

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
  connection,
  mentalModel,
  curiosity,
  plan,
}

/// An observation reflects the present; a plan looks ahead to next lessons.
enum ObservationKind { observation, plan }

/// One justifying fact behind an observation — e.g. ("Listening", "78%",
/// delta: +0.11). Rendered when the learner taps a note to ask "why?".
class Evidence {
  const Evidence(this.label, this.value, {this.delta});

  final String label;
  final String value;

  /// Optional signed change since the last session, as a 0…1 fraction.
  final double? delta;
}

/// One line in the notebook, with the evidence that supports it.
class TeacherObservation {
  const TeacherObservation(
    this.text, {
    required this.category,
    this.kind = ObservationKind.observation,
    this.priority = 5,
    this.evidence = const [],
    this.conceptIds = const [],
  });

  final String text;
  final ObservationCategory category;
  final ObservationKind kind;

  /// Lower shows first; used to rank when trimming to [maxNotes].
  final int priority;

  /// Facts that justify this note (may be empty for purely forward-looking
  /// plans). Never invented — sourced from the same metrics that produced it.
  final List<Evidence> evidence;

  /// Optional connection-graph nodes this note refers to — lets the UI jump
  /// from a note into the concepts behind it (Phase 18).
  final List<String> conceptIds;
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

/// A persisted metrics snapshot — the durable FACTS the brain remembers across
/// sessions. Only the numbers needed to render notes and compute trends are
/// stored; the prose is always regenerated live so it never goes stale.
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

String _pct(double v) => '${(v * 100).round()}%';

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

/// Builds the notebook observations from live learner facts. All inputs are
/// already summarized so the generator stays free of provider/store
/// dependencies. Called by the offline `ReasoningEngine`.
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
  ConnectionSuggestion? connectionSuggestion,
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

  // 1 · Recurring grammar mistakes — the teacher's top concern. One note per
  // CONCEPT: the same misconception can be tracked from several interference
  // sources, and rendering the identical sentence twice read as a bug on the
  // device (it was — two 'tener' entries, one note text).
  final ranked = [...misconceptions]
    ..sort((a, b) => b.occurrences.compareTo(a.occurrences));
  final notedConcepts = <String>{};
  for (final m in ranked) {
    if (notedConcepts.length >= 2) break;
    if (!notedConcepts.add(m.conceptId)) continue;
    final name = conceptNames[m.conceptId] ?? m.pattern;
    notes.add(
      TeacherObservation(
        'You keep slipping on $name (seen ${m.occurrences}×).',
        category: ObservationCategory.grammar,
        priority: 1,
        evidence: [
          Evidence(name, 'seen ${m.occurrences}×'),
          if (m.explanation.isNotEmpty) Evidence('Why', m.explanation),
        ],
        conceptIds: [m.conceptId, ...m.relatedConceptIds],
      ),
    );
  }

  // Teaching through connections: build outward from a known anchor.
  if (connectionSuggestion != null) {
    final s = connectionSuggestion;
    notes.add(
      TeacherObservation(
        'You already know ${s.anchorName} — '
        "let's connect it to ${s.relatedNames.join(', ')}.",
        category: ObservationCategory.connection,
        priority: 2,
        evidence: [Evidence(s.anchorName, 'known')],
        conceptIds: [s.anchorId, ...s.relatedIds],
      ),
    );
  }

  // 2 · Vocabulary progress against the level being learned.
  final vocab = mastery[LanguageSkill.vocabulary];
  if (vocab != null && vocab > 0) {
    notes.add(
      TeacherObservation(
        'You have mastered ${_pct(vocab)} of ${baseLevel.toUpperCase()} '
        'vocabulary.',
        category: ObservationCategory.vocabulary,
        priority: 4,
        evidence: [
          Evidence('${baseLevel.toUpperCase()} vocabulary', _pct(vocab)),
        ],
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
          '(${_pct(strong.value)}).',
          category: ObservationCategory.encouragement,
          priority: 4,
          evidence: [Evidence(strong.key.name, _pct(strong.value))],
        ),
      );
    }
    notes.add(
      TeacherObservation(
        "Let's give ${weak.key.name} more attention — it is lagging behind.",
        category: ObservationCategory.focus,
        priority: 2,
        evidence: [
          Evidence(weak.key.name, _pct(weak.value)),
          Evidence(strong.key.name, _pct(strong.value)),
        ],
      ),
    );
  }

  // 4 · Listening vs speaking balance — a recurring teaching theme.
  final listening = mastery[LanguageSkill.listening];
  final speaking = mastery[LanguageSkill.speaking];
  if (listening != null && speaking != null && listening > 0 && speaking > 0) {
    if ((listening - speaking).abs() > 0.1) {
      final evidence = [
        Evidence('Listening', _pct(listening)),
        Evidence('Speaking', _pct(speaking)),
      ];
      notes.add(
        listening > speaking
            ? TeacherObservation(
                'Listening is ahead of speaking — time to get you talking '
                'more.',
                category: ObservationCategory.speaking,
                priority: 3,
                evidence: evidence,
              )
            : TeacherObservation(
                'Your speaking is outpacing your listening — more audio '
                'input next.',
                category: ObservationCategory.listening,
                priority: 3,
                evidence: evidence,
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
              '(${_pct(pronunciationConfidence)}).',
              category: ObservationCategory.pronunciation,
              priority: 3,
              evidence: [
                Evidence('Pronunciation', _pct(pronunciationConfidence)),
              ],
            )
          : TeacherObservation(
              'Pronunciation needs steady drilling — short daily bursts help '
              'most.',
              category: ObservationCategory.pronunciation,
              priority: 3,
              evidence: [
                Evidence('Pronunciation', _pct(pronunciationConfidence)),
              ],
            ),
    );
  }

  // 6 · Trend vs the last session we recorded.
  if (previous != null) {
    final prevAvg = _avg(previous.mastery.values);
    final delta = avgMastery - prevAvg;
    final evidence = [
      Evidence('Overall mastery now', _pct(avgMastery), delta: delta),
      Evidence('Last session', _pct(prevAvg)),
    ];
    if (delta > 0.03) {
      notes.add(
        TeacherObservation(
          'Your overall mastery is up since we last worked together — keep '
          'this rhythm.',
          category: ObservationCategory.trend,
          priority: 2,
          evidence: evidence,
        ),
      );
    } else if (delta < -0.03) {
      notes.add(
        TeacherObservation(
          "You've slipped a little since last time — we'll review before "
          'moving on.',
          category: ObservationCategory.trend,
          priority: 2,
          evidence: evidence,
        ),
      );
    } else {
      notes.add(
        TeacherObservation(
          "You're holding steady — consistent practice is paying off.",
          category: ObservationCategory.trend,
          priority: 5,
          evidence: evidence,
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
