import 'connection_optimization.dart';
import 'conversation_continuity.dart';
import 'curriculum_intelligence.dart';
import 'learning_journey_engine.dart';
import 'lesson_outcomes.dart';
import 'message_intent.dart';
import 'recommendation_engine.dart';
import 'local_llm/llm_memory.dart';
import 'local_llm/llm_prompt_builder.dart';
import 'pipeline.dart';
import 'reader_intelligence.dart';
import 'relationships.dart';
import 'roleplay_engine.dart';
import 'teacher_brain.dart';
import 'teacher_intelligence.dart';
import 'teacher_memory_engine.dart';
import 'teaching_style.dart';

/// TeacherPacket (Phase 26): the ONLY thing a language generator may receive.
/// The local LLM never sees the raw Teacher Brain — this packet carries the
/// teacher's structured decisions plus exactly the context needed to word
/// them. Pure, deterministic, fully derived; empty fields mean "not measured/
/// not discussed", never guessed.
class TeacherPacket {
  const TeacherPacket({
    required this.plan,
    required this.continuation,
    required this.state,
    this.currentNode,
    this.journey,
    this.knownConcepts = const [],
    this.unknownConcepts = const [],
    this.connectionOpportunities = const [],
    this.mentalModelInsight,
    this.reflection,
    required this.correctionPolicy,
    required this.languagePolicy,
    this.teachingStyle,
    required this.objective,
    required this.summary,
    this.roleplay,
    this.lessonOutcomeSummary,
    this.recentEvents = const [],
    this.reflectionSummary,
    this.memory,
    this.recommendations = const [],
    this.journeyReport,
    this.reader,
    this.optimization,
    this.learnerFacts = const {},
  });

  final TeacherResponsePlan plan;
  final ConversationContinuation continuation;
  final ConversationState state;
  final CurriculumNode? currentNode;
  final LearningJourney? journey;
  final List<String> knownConcepts;
  final List<String> unknownConcepts;
  final List<String> connectionOpportunities;
  final String? mentalModelInsight;
  final ReflectionPlan? reflection;
  final String correctionPolicy;
  final String languagePolicy;
  final String? teachingStyle;
  final String objective;
  final ConversationSummary summary;

  /// The active/selected roleplay scenario (Phase 30), when one is running.
  final RoleplayScenario? roleplay;

  /// One-line summary of the most recent completed lesson.
  final String? lessonOutcomeSummary;

  /// Recent typed teacher events, most-relevant first (evidence strings).
  final List<String> recentEvents;

  /// One-line reflection summary from the last lesson.
  final String? reflectionSummary;

  /// Longitudinal teaching memory (Phase 31) — long-term trends, recurring
  /// misconceptions, recovered/forgotten skills, momentum.
  final TeacherMemorySummary? memory;

  /// Ranked recommendations (Phase 32) — top few, most important first.
  final List<Recommendation> recommendations;

  /// The active journey's health + prediction (Phase 32).
  final JourneyReport? journeyReport;

  /// Reader intelligence (Phase 33) — reading confidence, difficulty fit,
  /// habits, insights, prediction; null when the learner has not read.
  final ReaderProfile? reader;

  /// Connection-network optimization (Phase 34) — weak/strong/suggested
  /// bridges, cluster health, optimization score; null when no graph yet.
  final ConnectionOptimizationReport? optimization;

  /// Facts the learner EXPLICITLY shared in conversation (name, city, family,
  /// reasons for learning…). Stored verbatim, never inferred — see
  /// `message_intent.dart`. Empty when nothing has been shared.
  final Map<String, String> learnerFacts;
}

/// Assembles the packet from the brain + engines + live conversation. All
/// derived; the caller supplies the curriculum graph (static language
/// knowledge, not learner state).
TeacherPacket buildTeacherPacket({
  required TeacherBrain brain,
  required LanguageKnowledgeGraph graph,
  required ConversationContext context,
  required TeacherSupportMode supportMode,
  TeacherIntelligenceEngine intelligence = const TeacherIntelligenceEngine(),
  CurriculumIntelligenceEngine curriculum =
      const CurriculumIntelligenceEngine(),
  RoleplayScenario? roleplay,
  LessonResult? lastLesson,
  TeacherReflection? reflection,
  TeacherMemorySummary? memory,
  List<Recommendation> recommendations = const [],
  JourneyReport? journeyReport,
  ReaderProfile? reader,
  ConnectionOptimizationReport? optimization,
  Map<String, String> learnerFacts = const {},
}) {
  final plan = intelligence.plan(brain, turn: context.turns.length);
  final summary = summarizeConversation(context);
  final nextId = curriculum.nextToStudy(graph, brain);
  final journeys = curriculum.journeys(graph, brain);
  final known = [
    for (final e in brain.connections.nodes.entries)
      if (e.value.known) e.value.name,
  ];
  final unknown = [
    for (final e in brain.connections.nodes.entries)
      if (!e.value.known && e.value.mastery == 0) e.value.name,
  ];
  return TeacherPacket(
    plan: plan,
    continuation: buildContinuation(summary),
    state: intelligence.conversationState(brain, turn: context.turns.length),
    currentNode: nextId == null ? null : curriculum.node(nextId, graph, brain),
    journey: journeys.isEmpty ? null : journeys.first,
    knownConcepts: known.take(8).toList(),
    unknownConcepts: unknown.take(8).toList(),
    connectionOpportunities: [
      for (final s in brain.connections.suggestions.take(2)) s.rationale,
    ],
    mentalModelInsight:
        brain.mentalModels.isEmpty ? null : brain.mentalModels.first.insight,
    reflection: plan.reflection,
    correctionPolicy: brain.pedagogy == null
        ? 'gentle, one correction max'
        : '${brain.pedagogy!.correctionStyle.name}, one correction max',
    languagePolicy: supportMode == TeacherSupportMode.immersion
        ? 'target language only — no native support'
        : 'target language spoken; short native notes may follow as text',
    teachingStyle: brain.pedagogy?.style.name,
    objective: brain.objectives.current,
    summary: summary,
    roleplay: roleplay,
    lessonOutcomeSummary: lastLesson == null
        ? null
        : '${lastLesson.objective}: '
            '${lastLesson.conceptsMastered.length} mastered, '
            '${lastLesson.conceptsStruggled.length} to review',
    recentEvents: lastLesson == null
        ? const []
        : [for (final e in lastLesson.events.take(4)) '${e.kind.name}: ${e.evidence}'],
    reflectionSummary: reflection == null
        ? null
        : [
            if (reflection.whatImproved.isNotEmpty)
              'improved: ${reflection.whatImproved.first}',
            if (reflection.nextAdjustment != null) reflection.nextAdjustment,
          ].whereType<String>().join(' · '),
    memory: (memory == null || memory.isEmpty) ? null : memory,
    recommendations: recommendations.take(3).toList(),
    journeyReport: journeyReport,
    reader: (reader == null || reader.isEmpty) ? null : reader,
    optimization:
        (optimization == null || optimization.isEmpty) ? null : optimization,
    learnerFacts: learnerFacts,
  );
}

/// Serializes the packet for a generator prompt. No UI knows this format;
/// deterministic; omits what is absent.
String serializeTeacherPacket(TeacherPacket p) {
  final b = StringBuffer()
    ..writeln('OBJECTIVE: ${p.objective}')
    ..writeln('STAGE: ${p.state.stage.name} · INTENT: ${p.plan.moment.intent.name} '
        '· PACING: ${p.plan.pacing.name}')
    ..writeln('LANGUAGE POLICY: ${p.languagePolicy}')
    ..writeln('CORRECTION POLICY: ${p.correctionPolicy}');
  if (p.teachingStyle != null) b.writeln('STYLE: ${p.teachingStyle}');
  if (p.learnerFacts.isNotEmpty) {
    b.writeln('ABOUT THE LEARNER (they told you this — use it naturally): '
        '${factsBrief(p.learnerFacts)}');
  }
  if (p.continuation.opener != null) {
    b.writeln('CONTINUE THREAD (${p.continuation.thread}): '
        '${p.continuation.opener}');
  }
  if (p.journey != null) {
    b.writeln('JOURNEY: ${p.journey!.name} '
        '(${(p.journey!.progress * 100).round()}% travelled'
        '${p.journey!.currentStage == null ? '' : ', now at ${p.journey!.currentStage!.name}'})');
  }
  if (p.currentNode != null) {
    b.writeln('CURRICULUM NODE: ${p.currentNode!.name} '
        '(value ${p.currentNode!.teachingValue}, '
        'difficulty ${p.currentNode!.difficulty})');
  }
  if (p.knownConcepts.isNotEmpty) {
    b.writeln('KNOWN: ${p.knownConcepts.join(', ')}');
  }
  if (p.unknownConcepts.isNotEmpty) {
    b.writeln('NOT YET MET: ${p.unknownConcepts.join(', ')}');
  }
  for (final c in p.connectionOpportunities) {
    b.writeln('CONNECTION: $c');
  }
  if (p.mentalModelInsight != null) {
    b.writeln('MENTAL MODEL: ${p.mentalModelInsight}');
  }
  if (p.roleplay != null) {
    b.writeln('ROLEPLAY: ${p.roleplay!.title} '
        '(${p.roleplay!.difficulty.name}${p.roleplay!.resumed ? ', resumed' : ''}) '
        '— ${p.roleplay!.rationale}');
  }
  if (p.lessonOutcomeSummary != null) {
    b.writeln('LAST LESSON: ${p.lessonOutcomeSummary}');
  }
  if (p.reflectionSummary != null && p.reflectionSummary!.isNotEmpty) {
    b.writeln('REFLECTION (last): ${p.reflectionSummary}');
  }
  for (final e in p.recentEvents) {
    b.writeln('EVENT: $e');
  }
  if (p.reflection != null) {
    b.writeln('REFLECTION: ${[
      p.reflection!.improved,
      p.reflection!.needsWork,
      p.reflection!.next,
    ].whereType<String>().join(' · ')}');
  }
  final m = p.memory;
  if (m != null && !m.isEmpty) {
    b.writeln('MEMORY: ${m.lessonsCompleted} lessons · '
        'confidence ${m.confidenceTrend.name} · momentum ${m.learningMomentum}');
    if (m.recentAchievements.isNotEmpty) {
      b.writeln('ACHIEVED: ${m.recentAchievements.take(3).join(', ')}');
    }
    if (m.longTermWeaknesses.isNotEmpty) {
      b.writeln('LONG-TERM WEAK: ${m.longTermWeaknesses.join(', ')}');
    }
    if (m.recoveredSkills.isNotEmpty) {
      b.writeln('RECOVERED: ${m.recoveredSkills.join(', ')}');
    }
    if (m.forgottenSkills.isNotEmpty) {
      b.writeln('RECONNECT (faded): ${m.forgottenSkills.join(', ')}');
    }
    if (m.recurringMisconceptions.isNotEmpty) {
      b.writeln('RECURRING: ${m.recurringMisconceptions.join(', ')}');
    }
  }
  for (final r in p.recommendations) {
    b.writeln('RECOMMEND (${r.kind.name}, urgency ${r.urgency}): ${r.reason}');
  }
  final jr = p.journeyReport;
  if (jr != null) {
    b.writeln('JOURNEY HEALTH: ${jr.journey.name} is ${jr.health.name}'
        '${jr.prediction.nextMilestone == null ? '' : ' — next: ${jr.prediction.nextMilestone}'}'
        '${jr.prediction.likelyObstacle == null ? '' : ', watch ${jr.prediction.likelyObstacle}'}');
  }
  final rd = p.reader;
  if (rd != null && !rd.isEmpty) {
    b.writeln('READER: ${rd.booksRead} books · confidence '
        '${rd.readingConfidence} · ${rd.difficultyFit.name}');
    if (rd.insights.isNotEmpty) b.writeln('READING: ${rd.insights.first}');
    if (rd.prediction.nextReviewWords.isNotEmpty) {
      b.writeln('REVIEW WORDS: ${rd.prediction.nextReviewWords.join(', ')}');
    }
  }
  final opt = p.optimization;
  if (opt != null && !opt.isEmpty) {
    b.writeln('CONNECTIONS: health ${opt.health.name} · score '
        '${opt.optimizationScore} · ${opt.suggestedBridges.length} bridges');
    if (opt.suggestedBridges.isNotEmpty) {
      b.writeln('BRIDGE: ${opt.suggestedBridges.first.reason}');
    }
    if (opt.isolatedConcepts.isNotEmpty) {
      b.writeln('ISOLATED: ${opt.isolatedConcepts.take(3).join(', ')}');
    }
  }
  return b.toString().trim();
}

/// Bridges the packet into the existing prompt builder so a generator gets one
/// consistent prompt: packet brief as system context, constraints unchanged.
LlmPrompt packetPrompt({
  required TeacherPacket packet,
  required TeacherBrain brain,
  required ConversationContext context,
  required String userMessage,
  required TeacherSupportMode supportMode,
}) {
  final base = buildTeacherPrompt(
    brain: brain,
    plan: packet.plan,
    context: context,
    userMessage: userMessage,
    supportMode: supportMode,
  );
  return LlmPrompt(
    system: '${base.system}\n\n${serializeTeacherPacket(packet)}',
    user: base.user,
    constraints: base.constraints,
  );
}
