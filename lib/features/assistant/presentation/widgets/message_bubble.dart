import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/features/assistant/domain/chat_message.dart';
import 'package:servora/features/assistant/presentation/chat_controller.dart';

/// The assistant's avatar: a sparkle on the brand gradient with a thin gold ring.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.045),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.goldGradient,
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.heroGradient,
          ),
          child: Icon(
            Icons.auto_awesome,
            size: size * 0.46,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}

/// One chat bubble. Replies carry a "Browse services" shortcut; a failed message shows
/// what went wrong with a retry button.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.onRetry,
    required this.onBrowse,
    super.key,
  });

  final ChatMessage message;
  final VoidCallback onRetry;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = message.isUser;
    final failed = message.status == MessageStatus.failed;
    const r = Radius.circular(AppRadius.lg - 4);
    const tail = Radius.circular(6);

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: user ? AppColors.ink : AppColors.surface,
        border: user ? null : Border.all(color: AppColors.outline),
        boxShadow: user ? AppShadows.lifted : AppShadows.soft,
        // The corner nearest the sender is tucked in, like a speech tail.
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: user ? r : tail,
          bottomRight: user ? tail : r,
        ),
      ),
      child: Text(
        message.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: user ? Colors.white : AppColors.ink,
          height: 1.5,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: user
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!user) ...[
                const AssistantAvatar(size: 28),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Semantics(
                  label: user ? 'You said' : 'Assistant said',
                  container: true,
                  child: AnimatedOpacity(
                    opacity: message.status == MessageStatus.sending ? 0.7 : 1,
                    duration: AppMotion.fast,
                    child: bubble,
                  ),
                ),
              ),
            ],
          ),
          if (!user)
            Padding(
              padding: const EdgeInsets.only(left: 28 + AppSpacing.sm - 8),
              child: TextButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Browse services'),
              ),
            ),
          if (failed)
            Semantics(
              liveRegion: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    chatFailureMessage(message.failure),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "The assistant is typing": three bouncing dots in a reply bubble.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Assistant is typing',
      liveRegion: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const AssistantAvatar(size: 28),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md - 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.outline),
                boxShadow: AppShadows.soft,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg - 4),
                  topRight: Radius.circular(AppRadius.lg - 4),
                  bottomRight: Radius.circular(AppRadius.lg - 4),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: const BouncingDots(size: 7),
            ),
          ],
        ),
      ),
    );
  }
}
