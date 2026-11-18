import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/features/assistant/data/chat_repository.dart';
import 'package:servora/features/assistant/presentation/assistant_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_chat_repository.dart';

late FakeChatRepository repo;

Future<void> openAssistant(WidgetTester tester) async {
  useScreen(tester, width: 400, height: 800);
  repo = FakeChatRepository();
  await tester.pumpWidget(
    servoraApp(
      status: AuthStatus.authenticated,
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(navTab('Assistant'));
  await tester.pumpAndSettle();
}

Future<void> ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

void main() {
  testWidgets('shows starter suggestions and tapping one sends it', (
    tester,
  ) async {
    await openAssistant(tester);
    for (final question in starterQuestions) {
      expect(find.text(question), findsOneWidget);
    }

    await tester.tap(find.text(starterQuestions[1]));
    await tester.pumpAndSettle();

    expect(repo.calls.single.message, starterQuestions[1]);
    expect(find.text(starterQuestions[1]), findsOneWidget); // now a bubble
    expect(find.text(starterQuestions[0]), findsNothing); // chips are gone
  });

  testWidgets('sending shows the message, a typing indicator, then the reply', (
    tester,
  ) async {
    await openAssistant(tester);
    final pending = Completer<String>();
    repo.onSend = (_, _) => pending.future;

    await ask(tester, 'Something relaxing');
    expect(find.text('Something relaxing'), findsOneWidget);
    expect(find.bySemanticsLabel('Assistant is typing'), findsOneWidget);

    pending.complete('Swedish Massage, \$65.00, 60 min.');
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Assistant is typing'), findsNothing);
    expect(find.text('Swedish Massage, \$65.00, 60 min.'), findsOneWidget);
    expect(find.text('Something relaxing'), findsOneWidget);
  });

  testWidgets('a failed message shows an error and Retry resends it', (
    tester,
  ) async {
    await openAssistant(tester);
    repo.onSend = (_, _) async =>
        throw const ServerFailure(code: 'AI_UNAVAILABLE');

    await ask(tester, 'Hello');
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(
      find.text('The assistant is unavailable right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    repo.onSend = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.calls.map((c) => c.message), ['Hello', 'Hello']);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.textContaining('Swedish Massage'), findsOneWidget);
  });

  testWidgets('Browse services opens Home with the search field focused', (
    tester,
  ) async {
    await openAssistant(tester);
    await ask(tester, 'Recommend something');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse services'));
    await tester.pumpAndSettle();

    expect(find.text('Find a service'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode?.hasPrimaryFocus, isTrue);
  });
}
