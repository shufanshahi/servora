import 'package:servora/core/error/app_failure.dart';

enum ChatRole { user, assistant }

enum MessageStatus { sending, sent, failed }

/// One entry in the conversation shown on screen.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.status = MessageStatus.sent,
    this.failure,
  });

  final int id;
  final ChatRole role;
  final String text;
  final MessageStatus status;

  /// Why the message failed (set only when [status] is [MessageStatus.failed]).
  final AppFailure? failure;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({MessageStatus? status, AppFailure? failure}) =>
      ChatMessage(
        id: id,
        role: role,
        text: text,
        status: status ?? this.status,
        failure: status == MessageStatus.failed ? failure : null,
      );

  /// The shape the API expects in `history`.
  Map<String, String> toApiJson() => {
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'content': text,
  };
}
