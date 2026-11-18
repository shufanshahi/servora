import 'package:servora/features/assistant/data/chat_repository.dart';
import 'package:servora/features/assistant/domain/chat_message.dart';

/// A scriptable [ChatRepository]. By default every question is answered with [reply].
/// Set [onSend] to hold a call open or to throw an AppFailure.
class FakeChatRepository implements ChatRepository {
  String reply = 'Try the Swedish Massage: \$65.00 for 60 minutes.';
  Future<String> Function(String message, List<ChatMessage> history)? onSend;

  final List<({String message, List<ChatMessage> history})> calls = [];

  @override
  Future<String> send(String message, List<ChatMessage> history) {
    calls.add((message: message, history: List.of(history)));
    final handler = onSend;
    if (handler != null) return handler(message, history);
    return Future.value(reply);
  }
}
