import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/core/network/providers.dart';
import 'package:servora/features/assistant/domain/chat_message.dart';

/// Talks to the assistant endpoint. The app only ever calls Servora's own API; the AI
/// provider and its key exist solely on the server. Throws [AppFailure] on any failure.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  /// Sends [message] with recent [history] and returns the assistant's reply.
  Future<String> send(String message, List<ChatMessage> history) async {
    final response = await _api.post(
      '/ai/chat',
      body: {
        'message': message,
        'history': [for (final m in history) m.toApiJson()],
      },
    );
    final data = response.data;
    final reply = data is Map<String, dynamic> ? data['reply'] : null;
    if (reply is! String || reply.trim().isEmpty) throw const UnknownFailure();
    return reply;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
