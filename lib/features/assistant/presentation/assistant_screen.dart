import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/motion.dart';
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

    // Newest first, because the list is reversed so it stays pinned to the bottom.
    // Each bubble is keyed, so only new ones play their entrance.
    final items = <Widget>[
      if (chat.isWaiting) const FadeSlideIn(child: TypingIndicator()),
      for (final message in chat.messages.reversed)
        FadeSlideIn(
          key: ValueKey(message.id),
          offset: Offset(message.isUser ? 24 : -24, 12),
          duration: AppMotion.medium,
          child: MessageBubble(
            message: message,
            onRetry: () => unawaited(controller.retry(message.id)),
            onBrowse: _browse,
          ),
        ),
    ];

    return SafeArea(
      bottom: false,
      child: MaxContentWidth(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: chat.isEmpty
                  ? _Suggestions(onPick: _send)
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenGutter,
                        AppSpacing.md,
                        AppSpacing.screenGutter,
                        AppSpacing.md,
                      ),
                      children: items,
                    ),
            ),
            _Composer(
              controller: _input,
              enabled: !chat.isWaiting,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// The assistant's name, avatar and an "online" dot.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final large = MediaQuery.textScalerOf(context).scale(1) >= 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.sm,
      ),
      child: FadeSlideIn(
        offset: const Offset(0, -12),
        child: Row(
          children: [
            const AssistantAvatar(size: 44),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    header: true,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.6,
                      child: Text(
                        'Assistant',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  // Decorative status line, dropped when text is very large.
                  if (!large)
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Your personal service concierge',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The message box and send button, floating as one white pill.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    const transparent = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.transparent),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs + 2,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLength: maxMessageChars,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: onSend,
                decoration: const InputDecoration(
                  hintText: 'Ask about our services',
                  counterText: '',
                  fillColor: Colors.transparent,
                  border: transparent,
                  enabledBorder: transparent,
                  focusedBorder: transparent,
                  disabledBorder: transparent,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            PressableScale(
              enabled: enabled,
              child: AnimatedContainer(
                duration: AppMotion.medium,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: enabled ? AppColors.heroGradient : null,
                  color: enabled ? null : AppColors.surfaceMuted,
                  boxShadow: enabled ? AppShadows.glow : const [],
                ),
                child: IconButton(
                  tooltip: 'Send',
                  onPressed: enabled ? onSend : null,
                  color: Colors.white,
                  disabledColor: AppColors.inkMuted,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
          ],
        ),
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
    const icons = [
      Icons.spa_outlined,
      Icons.self_improvement_rounded,
      Icons.savings_outlined,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FadeSlideIn(child: Center(child: AssistantAvatar(size: 76))),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Column(
              children: [
                Text(
                  'How can I help today?',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ask about services and get recommendations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final (index, question) in starterQuestions.indexed) ...[
            FadeSlideIn.staggered(
              index: index,
              baseDelay: const Duration(milliseconds: 160),
              child: AppCard(
                onTap: () => onPick(question),
                semanticLabel: question,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      icons[index % icons.length],
                      color: AppColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        question,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
        ],
      ),
    );
  }
}
