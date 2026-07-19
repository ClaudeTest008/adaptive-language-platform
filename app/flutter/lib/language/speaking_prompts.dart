/// Curated Spanish speaking prompts (everyday domains).
///
/// The knowledge graph only yields lemmas and short example sentences, so
/// graph-derived drills are all "repeat this phrase" and there are few of
/// them. This is the hand-written pool that gives speaking practice real
/// breadth: articulation drills, full sentences, shadowing, open questions
/// and roleplay lines across greetings, travel, restaurant, shopping,
/// health, work, family and directions.
///
/// Pure data + pure construction. Deterministic order, no randomness.
library;

import 'entities.dart';
import 'speaking.dart';

/// One curated prompt before it is turned into a [SpeakingDrill].
class SpeakingPrompt {
  const SpeakingPrompt({
    required this.kind,
    required this.domain,
    required this.target,
    this.translation,
    this.scene,
  });

  final SpeakingDrillKind kind;

  /// Everyday domain slug (greetings, travel, restaurant, …).
  final String domain;

  /// Spanish text: the utterance to say, or — for
  /// [SpeakingDrillKind.spontaneous] — the question to answer.
  final String target;

  /// English rendering (the question itself, for spontaneous prompts).
  final String? translation;

  /// Scene set-up for a roleplay line.
  final String? scene;
}

/// Everyday domains covered by the pool, in a stable order.
const speakingDomains = <String>[
  'greetings',
  'travel',
  'restaurant',
  'shopping',
  'health',
  'work',
  'family',
  'directions',
];

/// The curated prompt pool, in declaration order.
const speakingPrompts = <SpeakingPrompt>[
  // ── pronunciation: single words and minimal pairs ──────────────────
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'greetings',
    target: 'buenos días',
    translation: 'good morning',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'greetings',
    target: 'encantado',
    translation: 'pleased to meet you',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'travel',
    target: 'equipaje',
    translation: 'luggage',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'travel',
    target: 'pero — perro',
    translation: 'but — dog (minimal pair: single vs. rolled r)',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'restaurant',
    target: 'cuchara — cuchillo',
    translation: 'spoon — knife',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'restaurant',
    target: 'desayuno',
    translation: 'breakfast',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'shopping',
    target: 'caro — carro',
    translation: 'expensive — car (minimal pair)',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'shopping',
    target: 'zapatería',
    translation: 'shoe shop',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'health',
    target: 'cabeza — cerveza',
    translation: 'head — beer (minimal pair)',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'health',
    target: 'farmacia',
    translation: 'pharmacy',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'work',
    target: 'reunión',
    translation: 'meeting',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'family',
    target: 'abuela — aguela',
    translation: 'grandmother — (the b sound, softened between vowels)',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'family',
    target: 'cuñado',
    translation: 'brother-in-law',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'directions',
    target: 'izquierda',
    translation: 'left',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.pronunciation,
    domain: 'directions',
    target: 'esquina',
    translation: 'corner',
  ),

  // ── listen and repeat: full everyday sentences ─────────────────────
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'greetings',
    target: 'Buenos días, ¿cómo está usted?',
    translation: 'Good morning, how are you?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'greetings',
    target: 'Mucho gusto, me llamo Ana.',
    translation: 'Nice to meet you, my name is Ana.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'travel',
    target: '¿A qué hora sale el próximo tren?',
    translation: 'What time does the next train leave?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'travel',
    target: 'Quisiera un billete de ida y vuelta.',
    translation: "I'd like a return ticket.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'restaurant',
    target: 'Para mí, la sopa del día, por favor.',
    translation: "I'll have the soup of the day, please.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'restaurant',
    target: '¿Me trae la cuenta, por favor?',
    translation: 'Could you bring me the bill, please?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'shopping',
    target: '¿Cuánto cuesta esta camisa?',
    translation: 'How much is this shirt?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'shopping',
    target: '¿Tiene esta chaqueta en una talla más grande?',
    translation: 'Do you have this jacket in a bigger size?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'health',
    target: 'Me duele la garganta desde ayer.',
    translation: "My throat has hurt since yesterday.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'health',
    target: 'Necesito una cita con el médico.',
    translation: 'I need an appointment with the doctor.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'work',
    target: 'Trabajo en una oficina en el centro.',
    translation: 'I work in an office downtown.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'work',
    target: 'La reunión empieza a las nueve y media.',
    translation: 'The meeting starts at half past nine.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'family',
    target: 'Tengo dos hermanos y una hermana menor.',
    translation: 'I have two brothers and a younger sister.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'family',
    target: 'Los domingos comemos en casa de mis padres.',
    translation: "On Sundays we eat at my parents' house.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'directions',
    target: 'Perdone, ¿dónde está la estación?',
    translation: 'Excuse me, where is the station?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.listenRepeat,
    domain: 'directions',
    target: 'Siga todo recto y gire a la derecha.',
    translation: 'Go straight on and turn right.',
  ),

  // ── shadowing: longer sentences, natural pace ──────────────────────
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'greetings',
    target:
        'Buenas tardes, me alegro mucho de verte otra vez por aquí después '
        'de tanto tiempo.',
    translation:
        "Good afternoon, I'm really glad to see you here again after so long.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'travel',
    target:
        'El vuelo sale a las siete de la mañana, así que tenemos que estar '
        'en el aeropuerto dos horas antes.',
    translation:
        'The flight leaves at seven in the morning, so we have to be at the '
        'airport two hours earlier.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'restaurant',
    target:
        'De primero voy a tomar una ensalada mixta y de segundo el pescado '
        'a la plancha, por favor.',
    translation:
        'For starters I will have a mixed salad and for the main course the '
        'grilled fish, please.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'shopping',
    target:
        'Me llevo estos pantalones, pero si no le quedan bien a mi hermano, '
        '¿puedo cambiarlos la semana que viene?',
    translation:
        "I'll take these trousers, but if they don't fit my brother, can I "
        'exchange them next week?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'health',
    target:
        'Llevo tres días con fiebre y dolor de cabeza, y anoche casi no pude '
        'dormir.',
    translation:
        "I've had a fever and a headache for three days, and last night I "
        'could hardly sleep.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'work',
    target:
        'Esta semana tengo mucho trabajo, pero el viernes por la tarde ya '
        'estaré libre para hablar contigo.',
    translation:
        "I have a lot of work this week, but by Friday afternoon I'll be "
        'free to talk with you.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'family',
    target:
        'Mi abuela vive en un pueblo pequeño cerca del mar y siempre nos '
        'prepara algo rico cuando vamos a visitarla.',
    translation:
        'My grandmother lives in a small village near the sea and she always '
        'makes us something delicious when we visit her.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'directions',
    target:
        'Cruce la plaza, pase por delante de la iglesia y el museo estará a '
        'mano izquierda, justo al lado del banco.',
    translation:
        'Cross the square, go past the church, and the museum will be on the '
        'left, right next to the bank.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'travel',
    target:
        'Si perdemos el autobús de las ocho, tendremos que esperar una hora '
        'entera hasta el siguiente.',
    translation:
        'If we miss the eight o\'clock bus, we\'ll have to wait a whole hour '
        'for the next one.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.shadowing,
    domain: 'restaurant',
    target:
        'Reservé una mesa para cuatro personas a nombre de García, pero '
        'somos cinco, ¿hay algún problema?',
    translation:
        'I booked a table for four under the name García, but there are five '
        'of us — is that a problem?',
  ),

  // ── spontaneous: open questions, never scored ──────────────────────
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'greetings',
    target: '¿Cómo te llamas y de dónde eres?',
    translation: "What's your name and where are you from?",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'greetings',
    target: '¿Qué tal ha ido tu día hoy?',
    translation: 'How has your day gone today?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'travel',
    target: '¿Cuál es el mejor viaje que has hecho?',
    translation: "What's the best trip you've taken?",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'travel',
    target: '¿Prefieres viajar en tren o en avión? ¿Por qué?',
    translation: 'Do you prefer travelling by train or plane? Why?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'restaurant',
    target: '¿Qué sueles pedir cuando sales a comer?',
    translation: 'What do you usually order when you eat out?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'shopping',
    target: '¿Qué fue lo último que compraste y para qué era?',
    translation: 'What was the last thing you bought, and what was it for?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'health',
    target: '¿Qué haces para cuidar tu salud durante la semana?',
    translation: 'What do you do to look after your health during the week?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'work',
    target: '¿En qué trabajas y qué es lo que más te gusta de tu trabajo?',
    translation: 'What do you do, and what do you like most about your job?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'work',
    target: '¿Cómo es un día normal para ti?',
    translation: 'What is a normal day like for you?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'family',
    target: '¿Cómo es tu familia? Descríbela.',
    translation: 'What is your family like? Describe it.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'family',
    target: '¿Qué haces normalmente los fines de semana con tu familia?',
    translation: 'What do you usually do at weekends with your family?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.spontaneous,
    domain: 'directions',
    target: '¿Cómo llegas desde tu casa hasta el centro?',
    translation: 'How do you get from your house to the town centre?',
  ),

  // ── roleplay: say your line in the scene ───────────────────────────
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'restaurant',
    scene: 'El camarero pregunta: «¿Qué va a tomar?»',
    target: 'Voy a tomar el menú del día y agua, por favor.',
    translation: "I'll have the set menu and water, please.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'restaurant',
    scene: 'Has terminado de comer y quieres pagar.',
    target: 'La cuenta, por favor. ¿Puedo pagar con tarjeta?',
    translation: 'The bill, please. Can I pay by card?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'travel',
    scene: 'En la estación, el empleado pregunta: «¿Adónde va?»',
    target: 'A Sevilla, en el tren de las diez, por favor.',
    translation: 'To Seville, on the ten o\'clock train, please.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'travel',
    scene: 'En el hotel, la recepcionista te saluda.',
    target: 'Buenas tardes, tengo una reserva a nombre de Martín.',
    translation: 'Good afternoon, I have a reservation under the name Martín.',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'shopping',
    scene: 'La dependienta pregunta: «¿Le puedo ayudar?»',
    target: 'Sí, busco un regalo para mi madre. ¿Qué me recomienda?',
    translation:
        "Yes, I'm looking for a present for my mother. What do you recommend?",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'shopping',
    scene: 'La camisa que compraste tiene un agujero.',
    target: 'Compré esta camisa ayer y está rota. Quisiera devolverla.',
    translation:
        "I bought this shirt yesterday and it's torn. I'd like to return it.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'health',
    scene: 'El médico pregunta: «¿Qué le pasa?»',
    target: 'Me duele el estómago y no tengo apetito desde el lunes.',
    translation: "My stomach hurts and I haven't had an appetite since Monday.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'health',
    scene: 'En la farmacia, quieres algo para la tos.',
    target: '¿Tiene algo para la tos que no lleve receta?',
    translation: 'Do you have something for a cough that needs no prescription?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'greetings',
    scene: 'Te presentan a un compañero nuevo.',
    target: 'Encantado, soy Luis. Trabajo en el equipo de diseño.',
    translation: "Pleased to meet you, I'm Luis. I work on the design team.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'work',
    scene: 'Tu jefe pregunta: «¿Cómo va el proyecto?»',
    target: 'Va bien, pero necesito dos días más para terminarlo.',
    translation: "It's going well, but I need two more days to finish it.",
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'directions',
    scene: 'Estás perdido y paras a alguien en la calle.',
    target: 'Perdone, ¿me puede decir cómo llegar al museo?',
    translation: 'Excuse me, can you tell me how to get to the museum?',
  ),
  SpeakingPrompt(
    kind: SpeakingDrillKind.roleplay,
    domain: 'family',
    scene: 'Un amigo pregunta por tu hermana.',
    target: 'Mi hermana está muy bien, ahora vive en Valencia.',
    translation: 'My sister is very well, she lives in Valencia now.',
  ),
];

/// Builds drills from the curated pool for [languageCode] (Spanish only —
/// the pool is Spanish content; other languages get an empty list rather
/// than mistranslated prompts).
///
/// Each prompt hangs off a synthesized `<lang>:a2:speaking:<domain>` node
/// so attempts record signals on a stable, honest concept id.
List<SpeakingDrill> curatedSpeakingDrills({String languageCode = 'es'}) {
  if (languageCode != 'es') return const [];
  final root = LanguageNode(
    tier: LanguageTier.language,
    slug: languageCode,
    name: languageCode,
  );
  final level = LanguageNode(
    tier: LanguageTier.level,
    slug: CefrLevel.a2.name,
    name: 'A2',
    parent: root,
  );
  final skill = LanguageNode(
    tier: LanguageTier.skill,
    slug: LanguageSkill.speaking.name,
    name: 'Speaking',
    parent: level,
  );
  final domains = {
    for (final d in speakingDomains)
      d: LanguageNode(
        tier: LanguageTier.domain,
        slug: d,
        name: d,
        parent: skill,
      ),
  };
  return [
    for (final p in speakingPrompts)
      SpeakingDrill(
        node: PhraseNode(
          slug: promptSlug(p.target),
          name: p.target,
          text: p.target,
          translation: p.translation,
          parent: domains[p.domain] ?? skill,
        ),
        target: p.target,
        translation: p.translation,
        kind: p.kind,
        scene: p.scene,
      ),
  ];
}

/// Stable kebab-case slug for a prompt (accents folded, first six words).
String promptSlug(String text) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  final buf = StringBuffer();
  for (final ch in text.toLowerCase().split('')) {
    buf.write(accents[ch] ?? ch);
  }
  final words = buf
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .take(6);
  return words.join('-');
}
