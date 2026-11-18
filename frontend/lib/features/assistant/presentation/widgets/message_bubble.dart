import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/features/assistant/domain/chat_message.dart';
import 'package:servora/features/assistant/presentation/chat_controller.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final user = message.isUser;
    final failed = message.status == MessageStatus.failed;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: user ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        message.text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: user ? scheme.onPrimary : scheme.onSurface),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Semantics(
            label: user ? 'You said' : 'Assistant said',
            container: true,
            child: Opacity(
              opacity: message.status == MessageStatus.sending ? 0.7 : 1,
              child: bubble,
            ),
          ),
          if (!user)
            TextButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Browse services'),
            ),
          if (failed)
            Semantics(
              liveRegion: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    chatFailureMessage(message.failure),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.error),
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

/// Three-dot style "assistant is typing" row.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Assistant is typing',
      liveRegion: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
