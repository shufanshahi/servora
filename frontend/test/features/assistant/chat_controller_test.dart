import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/features/assistant/data/chat_repository.dart';
import 'package:servora/features/assistant/domain/chat_message.dart';
import 'package:servora/features/assistant/presentation/chat_controller.dart';

import '../../support/fake_chat_repository.dart';

void main() {
  late FakeChatRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeChatRepository();
    container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  ChatController controller() =>
      container.read(chatControllerProvider.notifier);
  ChatState state() => container.read(chatControllerProvider);

  test('send shows the message at once, then appends the reply', () async {
    final pending = Completer<String>();
    repo.onSend = (_, _) => pending.future;

    final future = controller().send('  What is cheap?  ');
    expect(state().isWaiting, isTrue);
    expect(state().messages.single.text, 'What is cheap?');
    expect(state().messages.single.status, MessageStatus.sending);

    pending.complete('Manicure, \$25.');
    await future;

    expect(state().isWaiting, isFalse);
    expect(state().messages.map((m) => m.role), [
      ChatRole.user,
      ChatRole.assistant,
    ]);
    expect(state().messages.first.status, MessageStatus.sent);
    expect(state().messages.last.text, 'Manicure, \$25.');
  });

  test('ignores blank text and sends made while a reply is pending', () async {
    await controller().send('   ');
    expect(repo.calls, isEmpty);

    final pending = Completer<String>();
    repo.onSend = (_, _) => pending.future;
    final first = controller().send('one');
    await controller().send('two');
    expect(repo.calls, hasLength(1));
    pending.complete('ok');
    await first;
  });

  test(
    'a failure keeps the conversation and marks the message failed',
    () async {
      await controller().send('hello');
      repo.onSend = (_, _) async => throw const NetworkFailure();
      await controller().send('second');

      expect(state().isWaiting, isFalse);
      expect(state().messages, hasLength(3));
      final failed = state().messages.last;
      expect(failed.status, MessageStatus.failed);
      expect(failed.failure, isA<NetworkFailure>());
      expect(state().messages.first.text, 'hello');
    },
  );

  test('retry resends the same text and puts the reply after it', () async {
    repo.onSend = (_, _) async =>
        throw const ServerFailure(code: 'AI_UNAVAILABLE');
    await controller().send('hello');
    final id = state().messages.single.id;
    expect(
      chatFailureMessage(state().messages.single.failure),
      contains('unavailable'),
    );

    repo.onSend = null;
    repo.reply = 'Hi there';
    await controller().retry(id);

    expect(repo.calls.map((c) => c.message), ['hello', 'hello']);
    expect(state().messages.map((m) => m.status), [
      MessageStatus.sent,
      MessageStatus.sent,
    ]);
    expect(state().messages.last.text, 'Hi there');
  });

  test('history holds answered turns only, capped to the API limit', () async {
    for (var i = 0; i < 8; i++) {
      await controller().send('q$i'); // 16 messages (8 questions, 8 replies)
    }
    repo.onSend = (_, _) async => throw const NetworkFailure();
    await controller().send('unanswered');
    repo.onSend = null;
    await controller().send('latest');

    final history = repo.calls.last.history;
    expect(history, hasLength(maxHistoryMessages));
    expect(history.every((m) => m.status == MessageStatus.sent), isTrue);
    expect(history.map((m) => m.text), isNot(contains('unanswered')));
    expect(history.last.role, ChatRole.assistant);
  });
}
