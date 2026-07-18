/// Deterministic offline tutor (ADR-0018). Implements the SAME
/// [AiChatModel] seam a real vendor adapter will: it sees only the
/// messages — MODE tag, persona, dialogue plan, [LEARNER CONTEXT] block,
/// user turn — and composes mode-appropriate replies from what the
/// prompt actually says. Swapping in Anthropic/OpenAI/Gemini later is a
/// provider binding change only.
library;

import '../ai/chat_model.dart';

class DemoTutorModel implements AiChatModel {
  const DemoTutorModel();

  @override
  String get providerName => 'demo';

  @override
  Future<String> complete(List<AiMessage> messages) async {
    final system = messages
        .firstWhere(
          (m) => m.role == AiRole.system,
          orElse: () => const AiMessage(AiRole.system, ''),
        )
        .content;
    final user = messages.lastWhere((m) => m.role == AiRole.user).content;
    final turns = messages.where((m) => m.role == AiRole.assistant).length;
    final opening = turns == 0 || user == 'Start the session.';
    final c = _Context.parse(system);

    return switch (c.mode) {
      'teacher' => _teacher(c),
      'conversation' => _conversation(c, turns, user, opening),
      'coach' => _coach(c),
      'socratic' => _socratic(c, turns),
      'grammar' => _grammar(c),
      'immersion' => _immersion(c, turns, user, opening),
      _ => "Let's begin. You said: \"$user\" — tell me what you'd like to "
          'work on today.',
    };
  }

  String _teacher(_Context c) {
    final b = StringBuffer();
    if (c.focusName != null) {
      b.writeln("Let's work on **${c.focusName}**.");
      if (c.pattern != null) b.writeln('The pattern is ${c.pattern}.');
    } else if (c.weakest != null) {
      b.writeln("Looking at your progress, I'd start with your weakest "
          'area: ${c.weakest}.');
    }
    if (c.misconception != null) {
      b
        ..writeln()
        ..writeln('One thing I want to clear up first, because it keeps '
            'tripping you up: ${c.misconception}');
    }
    if (c.family.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Practice these together as one family: '
            '${c.family.join(", ")}.');
    }
    if (c.family.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Quick check: how would you say "${c.family.first}" in a '
            'full sentence?');
    }
    return b.toString().trim();
  }

  /// Multi-turn, contextual conversation: react to the learner's last
  /// message, weave a target-vocab phrase, progress the scenario, ask a
  /// natural follow-up. Warm, never a lecture.
  String _conversation(_Context c, int turns, String user, bool opening) {
    final vocab = c.targetVocab;
    final es = c.language == 'es';
    if (opening) {
      final scene = c.scenario ?? (es
          ? 'Estamos en un café pequeño.'
          : "We're meeting for the first time.");
      final v = vocab.isNotEmpty ? vocab.first : (es ? 'tener hambre' : 'hello');
      return es
          ? '¡Hola! $scene Yo soy tu compañero de conversación. '
                'Para empezar: ¿tú tienes hambre? Piensa en «$v».'
          : "Hi! $scene I'll be your conversation partner. "
                'To start — how are you today? Try using "$v".';
    }
    // React to what they said, use vocab, ask a follow-up. Progress the
    // scene by turn.
    final beat = _beat(turns, es);
    final react = es ? _reactEs(user) : _reactEn(user);
    final v = vocab.isEmpty
        ? ''
        : (es ? ' Prueba con «${vocab[turns % vocab.length]}».'
              : ' Try "${vocab[turns % vocab.length]}".');
    return '$react $beat$v';
  }

  String _beat(int turns, bool es) {
    final esBeats = [
      '¿Y qué te gustaría comer hoy?',
      'Muy bien. ¿Tienes sed también?',
      '¡Perfecto! ¿Prefieres algo caliente o frío?',
      'Genial. ¿Algo más para ti?',
    ];
    final enBeats = [
      'What do you like to do on weekends?',
      'Nice — where are you from?',
      'Good! And what did you do yesterday?',
      'Great. What are your plans for today?',
    ];
    final beats = es ? esBeats : enBeats;
    // Rotate (never clamp): the conversation must not repeat the same
    // question once the scene beats run out (Phase 21 duplicate-reply fix).
    return beats[(turns - 1) % beats.length];
  }

  String _reactEs(String user) {
    final u = user.trim();
    if (u.isEmpty) return 'Vale.';
    if (u.toLowerCase().contains('soy cansad')) {
      return '¡Ah! Recuerda: en español decimos «tengo sueño» o «estoy '
          'cansado», no «soy cansado». Bien dicho igualmente.';
    }
    // Vary acknowledgements deterministically so consecutive turns never
    // sound identical (Phase 21).
    const acks = ['¡Muy bien, te entiendo!', 'Perfecto.', '¡Claro que sí!',
        'Entiendo.'];
    return acks[u.length % acks.length];
  }

  String _reactEn(String user) {
    final u = user.trim();
    if (u.isEmpty) return 'Okay.';
    if (RegExp(r'^(is |are )', caseSensitive: false).hasMatch(u)) {
      return 'Nice — just remember to start with the subject, like '
          '"It is…". I understood you, though!';
    }
    return 'Great, I hear you!';
  }

  String _coach(_Context c) {
    final b = StringBuffer('Here is where you stand: ${c.skills ?? "no data yet"}.');
    if (c.weakest != null) {
      b
        ..writeln()
        ..writeln()
        ..writeln('Weakest right now: ${c.weakest}. My plan for today: '
            '10 minutes of repair there, then 5 minutes of review.');
    }
    if (c.goal != null) b.writeln('That keeps you on track for: ${c.goal}.');
    b
      ..writeln()
      ..writeln('Can you give me 15 minutes today?');
    return b.toString().trim();
  }

  String _socratic(_Context c, int turns) {
    if (turns == 0) {
      if (c.language == 'es') {
        return 'Think about "I am hungry". In English you use "to be". '
            'What did the Spanish phrases you learned — like '
            '"${c.family.isNotEmpty ? c.family.first : "tener hambre"}" — '
            'use instead?';
      }
      return 'Look at this sentence: "Is raining today." '
          'Something is missing at the start. What does every English '
          'sentence need before the verb?';
    }
    return 'Good thinking. And why would that verb make sense here — '
        'what does the phrase literally translate to?';
  }

  String _grammar(_Context c) {
    final b = StringBuffer();
    if (c.pattern != null) b.writeln('Pattern: ${c.pattern}.');
    if (c.misconception != null) {
      b.writeln('Contrast with your native language: ${c.misconception}');
    }
    if (c.family.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Minimal pairs to internalize: '
            '${c.family.map((f) => '"$f"').join(" · ")}.')
        ..writeln()
        ..writeln('Drill: transform "I am cold" using the pattern.');
    }
    return b.isEmpty
        ? 'Give me a sentence and I will break down its grammar.'
        : b.toString().trim();
  }

  /// Target-language-only, still contextual and progressing.
  String _immersion(_Context c, int turns, String user, bool opening) {
    final es = c.language == 'es';
    final vocab = c.targetVocab;
    if (es) {
      if (opening) {
        final v = vocab.isNotEmpty ? vocab.first : 'tener hambre';
        return '¡Hola! Vamos a hablar en español. Yo tengo hambre. '
            '¿Y tú? Usa «$v».';
      }
      // Distinct question every turn (Phase 21 duplicate-reply fix), each
      // reacting and connecting to the tener family the learner knows.
      const beats = [
        '¿Tú tienes frío o calor hoy?',
        '¿Y tienes sueño por la mañana o por la noche?',
        'Dime: ¿de qué tienes miedo?',
        '¿Tienes sed ahora? ¿Qué te gusta beber?',
        'Última pregunta: ¿tienes prisa hoy o tienes tiempo?',
      ];
      final v = vocab.isEmpty ? 'tener sueño' : vocab[turns % vocab.length];
      final react = _reactEs(user);
      return '$react ${beats[(turns - 1) % beats.length]} '
          'Funciona igual que «tener hambre». Puedes usar «$v».';
    }
    if (opening) {
      final v = vocab.isNotEmpty ? vocab.first : 'hello';
      return "Hello! Let's speak only in English today. How are you? "
          'Use "$v".';
    }
    return 'Good, I understand you! Now, what do you like to eat? '
        'Tell me in a full sentence.';
  }
}

/// Minimal parse of the tutor system prompt — the same fields a vendor
/// model reads in natural language.
class _Context {
  const _Context({
    required this.mode,
    required this.language,
    this.focusName,
    this.pattern,
    this.misconception,
    this.family = const [],
    this.weakest,
    this.skills,
    this.goal,
    this.scenario,
    this.targetVocab = const [],
  });

  final String mode;
  final String language; // target language code
  final String? focusName;
  final String? pattern;
  final String? misconception;
  final List<String> family;
  final String? weakest;
  final String? skills;
  final String? goal;

  /// Conversation scenario description (from the prompt).
  final String? scenario;

  /// Target-language phrases the tutor should weave in.
  final List<String> targetVocab;

  static _Context parse(String system) {
    String? line(String prefix) {
      for (final l in system.split('\n')) {
        if (l.startsWith(prefix)) return l.substring(prefix.length).trim();
      }
      return null;
    }

    final target = line('Target language: ');
    final code = RegExp(r'\((\w+)\)').firstMatch(target ?? '')?.group(1);
    final focus = line('Focus concept: ');
    final misconceptionRaw = line('Known misconception');
    final familyRaw = line('Pattern family: ');
    final weakRaw = line('Weak concepts (weakest first): ');
    final scenarioRaw = line('Scenario: ');
    final vocabRaw = line('Target vocabulary to weave in: ');

    return _Context(
      mode: line('MODE: ') ?? 'teacher',
      language: code ?? 'es',
      focusName: focus?.split(' — ').first.replaceAll('.', ''),
      pattern: focus != null && focus.contains('pattern:')
          ? focus.split('pattern:').last.trim().replaceAll(RegExp(r'\.$'), '')
          : null,
      misconception: misconceptionRaw
          ?.replaceFirst(RegExp(r'^\(\d+x\): '), '')
          .split('[concept:')
          .first
          .trim(),
      family: familyRaw == null
          ? const []
          : [
              for (final f in familyRaw.replaceAll('.', '').split(','))
                f.trim(),
            ],
      weakest: weakRaw?.split(';').first.trim(),
      skills: line('Skill mastery: ')?.replaceAll(RegExp(r'\.$'), ''),
      goal: line('Goals: ')?.replaceAll(RegExp(r'\.$'), ''),
      scenario: scenarioRaw,
      targetVocab: vocabRaw == null
          ? const []
          : [
              for (final v in vocabRaw.replaceAll(RegExp(r'\.$'), '').split(','))
                if (v.trim().isNotEmpty) v.trim(),
            ],
    );
  }
}
