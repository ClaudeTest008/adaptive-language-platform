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
    final c = _Context.parse(system);

    return switch (c.mode) {
      'teacher' => _teacher(c),
      'conversation' => _conversation(c, turns),
      'coach' => _coach(c),
      'socratic' => _socratic(c, turns),
      'grammar' => _grammar(c),
      'immersion' => _immersion(c, turns),
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

  String _conversation(_Context c, int turns) {
    final vocab = c.family.isNotEmpty ? c.family.first : c.weakest;
    if (c.language == 'es') {
      return turns == 0
          ? '¡Hola! Estamos en un restaurante. Yo soy el camarero. '
                '¿${_cap(vocab ?? "tener hambre")}? ¿Qué quieres comer?'
          : 'Muy bien. ¿Y para beber? (In a real conversation I keep '
                'adapting to your level.)';
    }
    return turns == 0
        ? "Hi! Let's chat. We are meeting for the first time — "
              'what is your name, and how are you today?'
        : 'Nice! Tell me more — what do you do every day? '
              '(Remember: every sentence needs its subject.)';
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

  String _immersion(_Context c, int turns) {
    if (c.language == 'es') {
      final family = c.family.isNotEmpty
          ? c.family.join(', ')
          : 'tener hambre, tener sueño';
      return turns == 0
          ? '¡Hola! Hoy practicamos: $family. Yo tengo hambre. ¿Tú también?'
          : '¡Muy bien! Otra vez: yo tengo frío. ¿Tú tienes frío o calor?';
    }
    return turns == 0
        ? 'Hello! Today we practice greetings. I am your tutor. '
              'How are you today?'
        : 'Great! Now ask me a question — remember the subject!';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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
    );
  }
}
