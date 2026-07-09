/// AI provider abstraction (ADR-0010). ONE seam for every vendor:
/// Anthropic, OpenAI, Gemini and local models each implement [AiChatModel];
/// everything above it (orchestrator, capabilities, UI) is provider-blind.
/// Pure Dart — no HTTP client here; adapters own their transport.
library;

enum AiRole { system, user, assistant }

class AiMessage {
  const AiMessage(this.role, this.content);

  final AiRole role;
  final String content;
}

/// Bounded conversation context: keeps the system message plus the most
/// recent turns so provider token limits are respected uniformly.
class AiConversation {
  AiConversation({required this.system, this.maxTurns = 20});

  final String system;
  final int maxTurns;
  final List<AiMessage> _turns = [];

  List<AiMessage> get messages => [
    AiMessage(AiRole.system, system),
    ..._turns.length <= maxTurns
        ? _turns
        : _turns.sublist(_turns.length - maxTurns),
  ];

  void addUser(String content) => _turns.add(AiMessage(AiRole.user, content));
  void addAssistant(String content) =>
      _turns.add(AiMessage(AiRole.assistant, content));
}

/// The single provider interface. Implementations: AnthropicChatModel,
/// OpenAiChatModel, GeminiChatModel, LocalChatModel (all land with API-key
/// configuration — network adapters are unverifiable until then, ADR-0010).
abstract class AiChatModel {
  String get providerName;
  Future<String> complete(List<AiMessage> messages);
}

/// Deterministic in-process model for tests and offline development.
/// Responds via a handler function; defaults to echoing the last user turn.
class FakeChatModel implements AiChatModel {
  FakeChatModel({String Function(List<AiMessage>)? handler})
    : _handler = handler ?? _echo;

  final String Function(List<AiMessage>) _handler;
  final List<List<AiMessage>> calls = [];

  static String _echo(List<AiMessage> messages) =>
      messages.lastWhere((m) => m.role == AiRole.user).content;

  @override
  String get providerName => 'fake';

  @override
  Future<String> complete(List<AiMessage> messages) async {
    calls.add(List.of(messages));
    return _handler(messages);
  }
}
