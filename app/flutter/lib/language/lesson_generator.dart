import 'connections.dart';
import 'mental_models.dart';
import 'recommendation_engine.dart';
import 'story.dart';
import 'teacher_brain.dart';

/// Adaptive Lesson Generator (Phase 19). Decides *what should happen next* by
/// deriving a structured plan from the Teacher Brain — the brain is the single
/// source of truth, this engine only reasons over it. Pure, deterministic,
/// offline; a premium planner can replace it while consuming the same brain.
///
/// It does not replace the existing daily-lesson engine (which feeds the
/// brain's objectives); it sits above it, turning the brain's understanding
/// into concrete, typed teaching recommendations.

enum LessonRecommendationKind {
  today,
  review,
  challenge,
  recovery,
  stretch,
  conversation,
  reading,
  speaking,
  grammar,
  vocabulary,
  story,
}

/// One typed recommendation, with the teacher's reason and the concepts it
/// touches. [activityHint] is a coarse route/surface hint for the UI.
class LessonRecommendation {
  const LessonRecommendation({
    required this.kind,
    required this.title,
    required this.rationale,
    this.conceptIds = const [],
    this.activityHint,
  });

  final LessonRecommendationKind kind;
  final String title;
  final String rationale;
  final List<String> conceptIds;
  final String? activityHint;
}

/// The plan the teacher proposes for the session, following the pedagogical arc
/// Known → Connected → New → Practice → Reflection → Connection review →
/// Mental model.
class LessonPlan {
  const LessonPlan({
    required this.todaysFocus,
    required this.steps,
    this.recommendations = const [],
    this.mentalModel,
  });

  final LessonRecommendation todaysFocus;
  final List<String> steps;

  /// Every recommendation produced this pass (today's focus first).
  final List<LessonRecommendation> recommendations;
  final MentalModel? mentalModel;

  LessonRecommendation? byKind(LessonRecommendationKind kind) {
    for (final r in recommendations) {
      if (r.kind == kind) return r;
    }
    return null;
  }
}

/// Generates an adaptive lesson plan from the brain.
class AdaptiveLessonGenerator {
  const AdaptiveLessonGenerator();

  LessonPlan generate(
    TeacherBrain brain, {
    List<Story> stories = const [],
    List<Recommendation> recommendations = const [],
  }) {
    final recs = <LessonRecommendation>[];
    final suggestion = brain.connections.suggestions.isEmpty
        ? null
        : brain.connections.suggestions.first;
    final model = brain.mentalModels.isEmpty ? null : brain.mentalModels.first;

    // Today's focus — the objective the brain is already tracking.
    final today = LessonRecommendation(
      kind: brain.objectives.currentConceptId != null
          ? LessonRecommendationKind.recovery
          : LessonRecommendationKind.today,
      title: brain.objectives.current,
      rationale: brain.objectives.currentConceptId != null
          ? 'This keeps tripping you up — we clear it, connected to what you '
                'already know.'
          : "Today's focus, from your progress.",
      conceptIds: [
        if (brain.objectives.currentConceptId != null)
          brain.objectives.currentConceptId!,
      ],
      activityHint: 'tutor',
    );
    recs.add(today);

    // Recovery (misconception) already folded into today's focus when present;
    // otherwise surface the weakest grammar as recovery.
    final weakGrammar = brain.facts.grammar
        .where((g) => g.status == GrammarStatus.weak)
        .toList()
      ..sort((a, b) => a.confidence.compareTo(b.confidence));
    if (weakGrammar.isNotEmpty) {
      recs.add(
        LessonRecommendation(
          kind: LessonRecommendationKind.grammar,
          title: weakGrammar.first.name,
          rationale: 'A grammar point that is still shaky — worth reinforcing.',
          conceptIds: [weakGrammar.first.conceptId],
          activityHint: 'practice',
        ),
      );
    }

    // Challenge / stretch — teach outward from a known anchor.
    if (suggestion != null) {
      recs.add(
        LessonRecommendation(
          kind: LessonRecommendationKind.stretch,
          title: 'Build on ${suggestion.anchorName}',
          rationale: suggestion.rationale,
          conceptIds: [suggestion.anchorId, ...suggestion.relatedIds],
          activityHint: 'tutor',
        ),
      );
    }

    // Review — concepts recently activated.
    if (brain.connections.recentlyActivated.isNotEmpty) {
      recs.add(
        LessonRecommendation(
          kind: LessonRecommendationKind.review,
          title: 'Quick review',
          rationale:
              "Five minutes on what we touched recently before moving on.",
          conceptIds: brain.connections.recentlyActivated.take(4).toList(),
          activityHint: 'practice',
        ),
      );
    }

    // Conversation topic — from the learner's strongest cluster (a real,
    // familiar domain) rather than a random scenario.
    final cluster = brain.connections.clusters.isEmpty
        ? null
        : brain.connections.clusters.first;
    recs.add(
      LessonRecommendation(
        kind: LessonRecommendationKind.conversation,
        title: cluster?.name ?? 'Everyday Spanish',
        rationale: 'A conversation built around ground you already stand on.',
        activityHint: 'tutor',
      ),
    );

    // Reading / story — the top level-matched story.
    if (stories.isNotEmpty) {
      final s = stories.first;
      recs.add(
        LessonRecommendation(
          kind: LessonRecommendationKind.story,
          title: s.title,
          rationale:
              '${s.level.name.toUpperCase()} reading matched to your level.',
          activityHint: 'story:${s.id}',
        ),
      );
    }

    // Speaking — reinforce whatever pronunciation the brain has measured.
    final pron = brain.facts.pronunciation.confidence;
    recs.add(
      LessonRecommendation(
        kind: LessonRecommendationKind.speaking,
        title: 'Pronunciation practice',
        rationale: pron == null
            ? "Let's start measuring your pronunciation."
            : 'Reinforce the sounds you are least sure of.',
        activityHint: 'speaking',
      ),
    );

    // Phase 33: the Recommendation Engine's top pick leads the plan (additive
    // — existing blocks remain). Recovery already leads via `today`, so a
    // recommendation only jumps ahead when it is not itself the recovery focus.
    final rec = recommendations.isEmpty ? null : recommendations.first;
    if (rec != null && rec.priority > 0) {
      recs.insert(
        1,
        LessonRecommendation(
          kind: _kindFor(rec.kind),
          title: 'Recommended: ${rec.kind.name}',
          rationale: rec.reason,
          conceptIds: rec.requiredConcepts,
          activityHint: _hintFor(rec.kind),
        ),
      );
    }

    return LessonPlan(
      todaysFocus: today,
      recommendations: recs,
      mentalModel: model,
      steps: _steps(brain, suggestion, model),
    );
  }

  LessonRecommendationKind _kindFor(RecommendationKind k) => switch (k) {
    RecommendationKind.conversation ||
    RecommendationKind.roleplay =>
      LessonRecommendationKind.conversation,
    RecommendationKind.reading || RecommendationKind.story =>
      LessonRecommendationKind.story,
    RecommendationKind.speaking => LessonRecommendationKind.speaking,
    RecommendationKind.review ||
    RecommendationKind.recoverWeakConcept =>
      LessonRecommendationKind.review,
    RecommendationKind.mentalModel ||
    RecommendationKind.connection =>
      LessonRecommendationKind.challenge,
    _ => LessonRecommendationKind.today,
  };

  String _hintFor(RecommendationKind k) => switch (k) {
    RecommendationKind.reading || RecommendationKind.story => 'story',
    RecommendationKind.speaking => 'speaking',
    _ => 'tutor',
  };

  List<String> _steps(
    TeacherBrain brain,
    ConnectionSuggestion? suggestion,
    MentalModel? model,
  ) {
    final known = suggestion?.anchorName;
    final related = suggestion?.relatedNames.join(', ');
    return [
      if (known != null) 'Known: start from what you know — $known.',
      if (related != null) 'Connected: bring in $related.',
      'New: ${brain.objectives.current}.',
      'Practice: a few short exercises.',
      'Reflection: notice what changed.',
      'Connection review: tie it back to earlier lessons.',
      if (model != null) 'Mental model: ${model.title}.',
    ];
  }
}
