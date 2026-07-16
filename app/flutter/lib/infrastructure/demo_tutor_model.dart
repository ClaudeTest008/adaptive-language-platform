/// Deterministic offline tutor (ADR-0018). Implements the SAME
/// [AiChatModel] seam a real vendor adapter will: it sees only the
/// messages — persona, [LEARNER CONTEXT] block, user turn — and composes
/// a teacherly reply from what the prompt actually says. Swapping in
/// Anthropic/OpenAI/Gemini later is a provider binding change only.
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

    String? line(String prefix) {
      for (final l in system.split('\n')) {
        if (l.startsWith(prefix)) return l.substring(prefix.length).trim();
      }
      return null;
    }

    final misconception = line('Known misconception');
    final focus = line('Focus concept: ');
    final family = line('Pattern family: ');
    final weak = line('Weak concepts (weakest first): ');
    final b = StringBuffer();

    if (focus != null) {
      final name = focus.split(' — ').first.replaceAll('.', '');
      b.writeln("Let's work on **$name**.");
      if (focus.contains('pattern:')) {
        b.writeln('The pattern is ${focus.split('pattern:').last.trim()}');
      }
    } else if (weak != null) {
      b.writeln(
        "Looking at your progress, I'd start with your weakest area: "
        '${weak.split(';').first.trim()}.',
      );
    }
    if (misconception != null) {
      final explanation = misconception
          .replaceFirst(RegExp(r'^\(\d+x\): '), '')
          .split('[concept:')
          .first
          .trim();
      b
        ..writeln()
        ..writeln(
          'One thing I want to clear up first, because it keeps tripping '
          'you up: $explanation',
        );
    }
    if (family != null) {
      b
        ..writeln()
        ..writeln(
          'Practice these together as one family: $family '
          'Say each one aloud — the pattern will start to feel natural.',
        );
    }
    if (b.isEmpty) {
      // No context to teach from — acknowledge the user turn.
      b.writeln(
        "Let's begin. You said: \"$user\" — tell me what you'd like to "
        'work on today.',
      );
    }
    return b.toString().trim();
  }
}
