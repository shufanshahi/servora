import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/features/assistant/presentation/chat_controller.dart';
import 'package:servora/features/assistant/presentation/widgets/message_bubble.dart';
import 'package:servora/features/services/presentation/services_providers.dart';

const starterQuestions = [
  'What services do you offer?',
  'Something relaxing that takes about an hour',
  "What's available under \$50?",
];

/// The Assistant tab: ask about services and get recommendations grounded in the
/// real catalogue (the answers come from the server, never directly from an AI provider).
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final value = text ?? _input.text;
    if (value.trim().isEmpty) return;
    _input.clear();
    unawaited(ref.read(chatControllerProvider.notifier).send(value));
  }

  void _browse() {
    ref.read(searchFocusRequestProvider.notifier).request();
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final theme = Theme.of(context);

    // Newest first, because the list is reversed so it stays pinned to the bottom.
    final items = <Widget>[
      if (chat.isWaiting) const TypingIndicator(),
      for (final message in chat.messages.reversed)
        MessageBubble(
          key: ValueKey(message.id),
          message: message,
          onRetry: () => unawaited(controller.retry(message.id)),
          onBrowse: _browse,
        ),
    ];

    return MaxContentWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text('Assistant', style: theme.textTheme.headlineSmall),
              ),
            ),
          ),
          Expanded(
            child: chat.isEmpty
                ? _Suggestions(onPick: _send)
                : ListView(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: items,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !chat.isWaiting,
                    maxLength: maxMessageChars,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Ask about our services',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: chat.isWaiting ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ask about services and get recommendations.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final question in starterQuestions)
                ActionChip(
                  label: Text(question),
                  onPressed: () => onPick(question),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
