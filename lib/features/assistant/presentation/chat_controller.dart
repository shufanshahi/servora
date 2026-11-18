import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/features/assistant/data/chat_repository.dart';
import 'package:servora/features/assistant/domain/chat_message.dart';

/// Matches the API's default `AI_MAX_HISTORY_MESSAGES`; older turns would be dropped by
/// the server anyway, so they are not sent.
const maxHistoryMessages = 10;

/// The API's default `AI_MAX_MESSAGE_CHARS`.
const maxMessageChars = 1000;

class ChatState {
  const ChatState({this.messages = const [], this.isWaiting = false});

  final List<ChatMessage> messages;

  /// A request is in flight (drives the typing indicator).
  final bool isWaiting;

  bool get isEmpty => messages.isEmpty;
}

/// The conversation. Held in memory only; it is not saved between app launches.
class ChatController extends Notifier<ChatState> {
  int _nextId = 0;

  @override
  ChatState build() => const ChatState();

  /// Adds the user's message and asks the assistant. Ignored while a reply is pending
  /// or when [text] is blank.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isWaiting) return;
    final message = ChatMessage(
      id: _nextId++,
      role: ChatRole.user,
      text: trimmed.length > maxMessageChars
          ? trimmed.substring(0, maxMessageChars)
          : trimmed,
      status: MessageStatus.sending,
    );
    state = ChatState(messages: [...state.messages, message], isWaiting: true);
    await _request(message.id);
  }

  /// Tries a failed message again.
  Future<void> retry(int id) async {
    if (state.isWaiting) return;
    final index = state.messages.indexWhere((m) => m.id == id);
    if (index < 0 || state.messages[index].status != MessageStatus.failed) {
      return;
    }
    _replace(id, (m) => m.copyWith(status: MessageStatus.sending));
    state = ChatState(messages: state.messages, isWaiting: true);
    await _request(id);
  }

  Future<void> _request(int id) async {
    final index = state.messages.indexWhere((m) => m.id == id);
    final message = state.messages[index];
    // Only turns that were answered count as context, and only the latest few.
    final history = state.messages
        .take(index)
        .where((m) => m.status == MessageStatus.sent)
        .toList();
    final capped = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    try {
      final reply = await ref
          .read(chatRepositoryProvider)
          .send(message.text, capped);
      if (!ref.mounted) return;
      final messages = [...state.messages];
      final at = messages.indexWhere((m) => m.id == id);
      messages[at] = messages[at].copyWith(status: MessageStatus.sent);
      messages.insert(
        at + 1,
        ChatMessage(id: _nextId++, role: ChatRole.assistant, text: reply),
      );
      state = ChatState(messages: messages);
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      _replace(
        id,
        (m) => m.copyWith(status: MessageStatus.failed, failure: failure),
      );
      state = ChatState(messages: state.messages);
    }
  }

  void _replace(int id, ChatMessage Function(ChatMessage) change) {
    state = ChatState(
      messages: [for (final m in state.messages) m.id == id ? change(m) : m],
      isWaiting: state.isWaiting,
    );
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// Friendly text for a failed message.
String chatFailureMessage(AppFailure? failure) {
  if (failure?.code == 'AI_UNAVAILABLE') {
    return 'The assistant is unavailable right now.';
  }
  return failure?.userMessage ?? 'Something went wrong. Please try again.';
}
