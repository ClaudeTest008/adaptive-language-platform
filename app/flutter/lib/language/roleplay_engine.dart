import 'conversation_continuity.dart';
import 'learning_profile.dart';
import 'teacher_brain.dart';
import 'speaking_session.dart';

/// Adaptive Roleplay Engine (Phase 30). Pure, deterministic, offline. It
/// decides WHICH scenario to run and how hard, from the learner's real state —
/// never randomly. Roleplays evolve through stages (open → ask → handle a
/// mistake → an unexpected turn → natural conversation) rather than isolated
/// drills. Consumes only the Teacher Brain and the conversation continuation;
/// stores no learner state.

enum RoleplayKind {
  conversation,
  restaurant,
  airport,
  hotel,
  shopping,
  doctor,
  friends,
  directions,
  story,
  problemSolving,
}

enum RoleplayDifficulty { gentle, standard, stretch }

class RoleplayGoal {
  const RoleplayGoal(this.description);
  final String description;
}

class RoleplayPrompt {
  const RoleplayPrompt(this.text);
  final String text;
}

/// One stage of an evolving scenario.
class RoleplayStage {
  const RoleplayStage({
    required this.name,
    required this.goal,
    required this.prompt,
  });
  final String name;
  final RoleplayGoal goal;
  final RoleplayPrompt prompt;
}

class RoleplayScenario {
  const RoleplayScenario({
    required this.kind,
    required this.title,
    required this.setting,
    required this.difficulty,
    required this.stages,
    required this.focusConceptIds,
    required this.rationale,
    this.resumed = false,
  });

  final RoleplayKind kind;
  final String title;
  final String setting;
  final RoleplayDifficulty difficulty;
  final List<RoleplayStage> stages;
  final List<String> focusConceptIds;

  /// Why the teacher chose this scenario — explainable.
  final String rationale;

  /// True when this continues an interrupted roleplay.
  final bool resumed;
}

/// Live progress through a scenario (derived; not a store).
class RoleplayProgress {
  const RoleplayProgress({
    required this.scenario,
    this.currentStageIndex = 0,
    this.done = false,
  });

  final RoleplayScenario scenario;
  final int currentStageIndex;
  final bool done;

  RoleplayStage? get currentStage =>
      done || currentStageIndex >= scenario.stages.length
          ? null
          : scenario.stages[currentStageIndex];

  double get fraction =>
      scenario.stages.isEmpty ? 1 : currentStageIndex / scenario.stages.length;
}

/// The teacher's response to a learner turn within a stage.
class RoleplayFeedback {
  const RoleplayFeedback({required this.message, required this.advance});
  final String message;
  final bool advance;
}

class RoleplayCompletion {
  const RoleplayCompletion({
    required this.scenario,
    required this.stagesCompleted,
    required this.success,
  });
  final RoleplayScenario scenario;
  final int stagesCompleted;
  final bool success;
}

const _topicKind = <String, RoleplayKind>{
  'travel': RoleplayKind.airport,
  'food': RoleplayKind.restaurant,
  'family': RoleplayKind.friends,
  'work': RoleplayKind.problemSolving,
  'nature': RoleplayKind.directions,
  'technology': RoleplayKind.problemSolving,
};

const _settings = <RoleplayKind, ({String title, String setting})>{
  RoleplayKind.conversation: (title: 'A friendly chat', setting: 'un café tranquilo'),
  RoleplayKind.restaurant: (title: 'At the restaurant', setting: 'un restaurante'),
  RoleplayKind.airport: (title: 'At the airport', setting: 'el aeropuerto'),
  RoleplayKind.hotel: (title: 'Checking into a hotel', setting: 'la recepción del hotel'),
  RoleplayKind.shopping: (title: 'At the market', setting: 'el mercado'),
  RoleplayKind.doctor: (title: "At the doctor's", setting: 'la consulta del médico'),
  RoleplayKind.friends: (title: 'With friends', setting: 'una reunión con amigos'),
  RoleplayKind.directions: (title: 'Asking directions', setting: 'una calle desconocida'),
  RoleplayKind.story: (title: 'Telling a story', setting: 'una charla relajada'),
  RoleplayKind.problemSolving: (title: 'Solving a problem', setting: 'una situación inesperada'),
};

/// Builds the evolving five-stage arc for a scenario.
List<RoleplayStage> _stages(RoleplayKind kind) {
  final s = _settings[kind]!;
  return [
    RoleplayStage(
      name: 'open',
      goal: const RoleplayGoal('Start the interaction naturally.'),
      prompt: RoleplayPrompt('Estamos en ${s.setting}. Empecemos: salúdame.'),
    ),
    const RoleplayStage(
      name: 'ask',
      goal: RoleplayGoal('Ask for what you need.'),
      prompt: RoleplayPrompt('Muy bien. Ahora, ¿qué necesitas? Pídelo.'),
    ),
    const RoleplayStage(
      name: 'handle-mistake',
      goal: RoleplayGoal('Recover from a small misunderstanding.'),
      prompt: RoleplayPrompt('Perdona, no entendí bien. ¿Puedes decirlo de otra forma?'),
    ),
    const RoleplayStage(
      name: 'unexpected',
      goal: RoleplayGoal('React to an unexpected turn.'),
      prompt: RoleplayPrompt('¡Ah! Hay un pequeño problema. ¿Qué hacemos?'),
    ),
    const RoleplayStage(
      name: 'natural',
      goal: RoleplayGoal('Hold a natural closing exchange.'),
      prompt: RoleplayPrompt('Perfecto. Charlemos un poco más antes de terminar.'),
    ),
  ];
}

/// Chooses the scenario deterministically from the brain (and any interrupted
/// roleplay to resume). Recovery → gentle; strained motivation → gentle;
/// confident + easy → stretch.
/// Maps an explicit learner scene request ("you are a waiter", "let's practice
/// ordering food", "at the hotel") to a scenario kind. Null when no known
/// scene is named. Deterministic keyword match — the learner's stated wish
/// always wins over interest-based selection.
RoleplayKind? roleplayKindFromRequest(String message) {
  final m = message.toLowerCase();
  bool has(String re) => RegExp(re, caseSensitive: false).hasMatch(m);
  if (has(r'\b(waiter|server|restaurant|order(ing)?\s+(food|a\s+meal|coffee)|'
      r'menu|dinner|lunch|breakfast|camarero|mesero|restaurante|comida)\b')) {
    return RoleplayKind.restaurant;
  }
  if (has(r'\b(airport|flight|boarding|aeropuerto|vuelo|check\s?in)\b')) {
    return RoleplayKind.airport;
  }
  if (has(r'\b(hotel|reception(ist)?|room\s+key|recepci[oó]n|habitaci[oó]n)\b')) {
    return RoleplayKind.hotel;
  }
  if (has(r'\b(shop(ping)?|market|store|buy(ing)?|mercado|tienda|comprar)\b')) {
    return RoleplayKind.shopping;
  }
  if (has(r'\b(doctor|clinic|hospital|pharmacy|m[eé]dico|farmacia|s[ií]ntoma)\b')) {
    return RoleplayKind.doctor;
  }
  if (has(r'\b(directions|how\s+to\s+get\s+to|lost|direcciones|c[oó]mo\s+llego)\b')) {
    return RoleplayKind.directions;
  }
  if (has(r'\b(friends?|amigos?)\b')) return RoleplayKind.friends;
  return null;
}

RoleplayScenario selectRoleplay(
  TeacherBrain brain, {
  ConversationContinuation? continuation,
  RoleplayKind? requestedKind,
}) {
  final recovery = brain.pedagogy?.recoveryMode ?? false;
  final strained = brain.profile.motivation.state == MotivationState.strained;
  final focus = <String>[
    if (brain.objectives.currentConceptId != null)
      brain.objectives.currentConceptId!,
  ];

  // An explicit request overrides everything — build that exact scene.
  if (requestedKind != null) {
    final s = _settings[requestedKind]!;
    return RoleplayScenario(
      kind: requestedKind,
      title: s.title,
      setting: s.setting,
      difficulty: (recovery || strained)
          ? RoleplayDifficulty.gentle
          : RoleplayDifficulty.standard,
      stages: _stages(requestedKind),
      focusConceptIds: focus,
      rationale: 'You asked for this scene — let’s do it.',
    );
  }

  // Resume an interrupted roleplay first.
  if (continuation?.thread == 'roleplay') {
    return RoleplayScenario(
      kind: RoleplayKind.conversation,
      title: 'Continue our scene',
      setting: continuation!.opener ?? 'donde lo dejamos',
      difficulty: recovery || strained
          ? RoleplayDifficulty.gentle
          : RoleplayDifficulty.standard,
      stages: _stages(RoleplayKind.conversation),
      focusConceptIds: focus,
      rationale: 'Picking up the roleplay we left unfinished.',
      resumed: true,
    );
  }

  // Recovery → a gentle, low-pressure conversation, no new scenario.
  final kind = (recovery || strained)
      ? RoleplayKind.conversation
      : (brain.interests.isEmpty
          ? RoleplayKind.conversation
          : _topicKind[brain.interests.first.topic] ??
              RoleplayKind.conversation);

  final tooEasy = brain.pedagogy?.difficulty.name == 'tooEasy';
  final confident = brain.profile.confidence.overall >= 0.7;
  final difficulty = (recovery || strained)
      ? RoleplayDifficulty.gentle
      : (tooEasy && confident)
      ? RoleplayDifficulty.stretch
      : RoleplayDifficulty.standard;

  final s = _settings[kind]!;
  return RoleplayScenario(
    kind: kind,
    title: s.title,
    setting: s.setting,
    difficulty: difficulty,
    stages: _stages(kind),
    focusConceptIds: focus,
    rationale: recovery
        ? 'Recovery mode — a gentle, familiar conversation.'
        : brain.interests.isEmpty
        ? 'A general conversation to keep momentum.'
        : 'Built around your interest in ${brain.interests.first.topic}.',
  );
}

/// The teacher's feedback to a learner turn, advancing on a solid attempt.
RoleplayFeedback roleplayFeedback(RoleplayProgress progress, SpeakingSession s) {
  final ok = s.completed && s.pronunciation >= 0.6;
  return RoleplayFeedback(
    message: ok
        ? '¡Muy bien! Sigamos.'
        : 'Casi. Inténtalo otra vez, sin prisa.',
    advance: ok,
  );
}

/// Advances the scenario one stage (or completes it).
RoleplayProgress advanceRoleplay(RoleplayProgress p) {
  final next = p.currentStageIndex + 1;
  return RoleplayProgress(
    scenario: p.scenario,
    currentStageIndex: next,
    done: next >= p.scenario.stages.length,
  );
}

/// Summarizes a finished (or abandoned) scenario.
RoleplayCompletion completeRoleplay(RoleplayProgress p) => RoleplayCompletion(
  scenario: p.scenario,
  stagesCompleted: p.currentStageIndex.clamp(0, p.scenario.stages.length),
  success: p.done,
);
