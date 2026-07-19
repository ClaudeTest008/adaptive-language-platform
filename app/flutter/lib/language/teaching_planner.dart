import 'connections.dart';
import 'entities.dart';
import 'recommendation_engine.dart';
import 'teacher_brain.dart';
import 'tutor.dart';

/// The unified teacher's decision (Phase 18): which internal strategy to run,
/// what to focus on, and — in the teacher's voice — why. Chosen automatically
/// from the Teacher Brain so the learner never picks a "mode".
class TeachingChoice {
  const TeachingChoice({
    required this.mode,
    required this.rationale,
    this.focusConceptId,
    this.connection,
  });

  final TutorMode mode;
  final String rationale;
  final String? focusConceptId;

  /// The connection this lesson builds on, when there is one to teach from.
  final ConnectionSuggestion? connection;
}

/// The connection anchored on [conceptId], its domain, or the strongest
/// available — so a repair lesson can teach outward from known ground.
ConnectionSuggestion? _connectionFor(TeacherBrain brain, String? conceptId) {
  final suggestions = brain.connections.suggestions;
  if (suggestions.isEmpty) return null;
  if (conceptId != null) {
    final domain = domainAncestor(conceptId);
    for (final s in suggestions) {
      if (s.anchorId == conceptId || domainAncestor(s.anchorId) == domain) {
        return s;
      }
    }
  }
  return suggestions.first;
}

/// Chooses the teaching strategy deterministically from the brain. Priority:
/// repair a current misconception (teaching it through its connections) →
/// get a lagging speaker talking → build outward from a strong anchor →
/// general teacher review. Pure and offline; a premium planner can replace
/// this while consuming the same brain.
TeachingChoice chooseTeachingStrategy(
  TeacherBrain brain, {
  List<Recommendation> recommendations = const [],
}) {
  // 0 · Recovery beats everything (Phase 20): sustained struggle or material
  // running too hard — review, no new concepts.
  final pedagogy = brain.pedagogy;
  if (pedagogy != null && pedagogy.recoveryMode) {
    return TeachingChoice(
      mode: TutorMode.teacher,
      focusConceptId: brain.objectives.currentConceptId,
      rationale: pedagogy.rationale,
    );
  }

  final focusId = brain.objectives.currentConceptId;

  // 1 · An active misconception: teach it, connected to what they know.
  if (focusId != null) {
    final connection = _connectionFor(brain, focusId);
    // A concept is never "connected to itself": the suggestion's related list
    // can contain the focus concept (same domain), which produced rationales
    // like "connect tener for physical states to tener for physical states".
    final focusName = brain.objectives.current;
    final related = connection == null
        ? const <String>[]
        : [
            for (final n in connection.relatedNames)
              if (n != focusName && n != connection.anchorName) n,
          ];
    final rationale = related.isEmpty
        ? "Let's focus on $focusName and tie it to what you already know."
        : 'You keep working on $focusName — '
            "let's connect it to ${related.join(', ')}.";
    return TeachingChoice(
      mode: TutorMode.teacher,
      focusConceptId: focusId,
      rationale: rationale,
      connection: connection,
    );
  }

  // 2 · A lagging speaking/conversation skill: get them talking.
  final skills = brain.facts.skills;
  double lvl(LanguageSkill s) => skills[s]?.level ?? 1;
  final speaking = lvl(LanguageSkill.speaking);
  final conversation = lvl(LanguageSkill.conversation);
  final talk = speaking < conversation ? speaking : conversation;
  final others = [
    for (final e in skills.entries)
      if (e.key != LanguageSkill.speaking &&
          e.key != LanguageSkill.conversation)
        e.value.level,
  ];
  final avgOthers = others.isEmpty
      ? 1.0
      : others.reduce((a, b) => a + b) / others.length;
  if (talk < 0.4 && talk < avgOthers) {
    return const TeachingChoice(
      mode: TutorMode.conversation,
      rationale: "Let's get you talking — your speaking is ready to catch up.",
    );
  }

  // 3 · Build outward from a strong anchor into unmet, related concepts.
  final suggestion = brain.connections.suggestions.isEmpty
      ? null
      : brain.connections.suggestions.first;
  if (suggestion != null) {
    return TeachingChoice(
      mode: TutorMode.teacher,
      focusConceptId: suggestion.anchorId,
      rationale: suggestion.rationale,
      connection: suggestion,
    );
  }

  // 4 · No pressing repair/skill gap — let the Recommendation Engine steer
  // (Phase 33 integration). Only the branches ABOVE (recovery, misconception,
  // lagging speaker, strong-anchor) take precedence; here a top recommendation
  // picks the mode when it maps to one. Deterministic and additive.
  final rec = recommendations.isEmpty ? null : recommendations.first;
  if (rec != null) {
    final mode = switch (rec.kind) {
      RecommendationKind.conversation ||
      RecommendationKind.roleplay ||
      RecommendationKind.speaking =>
        TutorMode.conversation,
      RecommendationKind.mentalModel ||
      RecommendationKind.connection ||
      RecommendationKind.recoverWeakConcept ||
      RecommendationKind.review =>
        TutorMode.teacher,
      _ => null,
    };
    if (mode != null) {
      return TeachingChoice(
        mode: mode,
        focusConceptId:
            rec.requiredConcepts.isEmpty ? null : rec.requiredConcepts.first,
        rationale: rec.reason,
      );
    }
  }

  // 5 · General teacher review.
  return const TeachingChoice(
    mode: TutorMode.teacher,
    rationale: "Let's review and strengthen what you've been learning.",
  );
}
