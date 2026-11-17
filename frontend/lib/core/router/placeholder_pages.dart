import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/loading_view.dart';

/// Temporary screens for the four tabs and the auth routes. Each is replaced by its
/// own feature change; they exist so navigation, state preservation and responsive
/// layout can be built and tested now.

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: LoadingView(message: 'Starting Servora'));
}

/// Stand-in for the sign-in screen until it is built in the authentication change.
class LoginPlaceholderPage extends StatelessWidget {
  const LoginPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyView(
        title: 'Servora',
        message: 'Sign in screen coming soon',
        icon: Icons.lock_outline,
      ),
    );
  }
}

/// Home placeholder: a long adaptive grid so scroll preservation can be tested.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return AdaptiveGrid(
      controller: controller,
      children: [
        for (var i = 1; i <= 40; i++)
          AppCard(
            child: Text(
              'Placeholder service $i',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
    );
  }
}

class BookingsPlaceholderPage extends StatelessWidget {
  const BookingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) => const MaxContentWidth(
    child: EmptyView(
      title: 'No bookings yet',
      message: 'Your upcoming and previous bookings will appear here.',
      icon: Icons.calendar_month_outlined,
    ),
  );
}

class AssistantPlaceholderPage extends StatelessWidget {
  const AssistantPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) => const MaxContentWidth(
    child: EmptyView(
      title: 'Assistant',
      message: 'Ask about services and get recommendations. Coming soon.',
      icon: Icons.chat_bubble_outline,
    ),
  );
}

class ProfilePlaceholderPage extends ConsumerWidget {
  const ProfilePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaxContentWidth(
      child: EmptyView(
        title: 'Profile',
        message: 'Your details will appear here.',
        icon: Icons.person_outline,
        actionLabel: 'Sign out',
        onAction: () => unawaited(ref.read(sessionProvider.notifier).logout()),
      ),
    );
  }
}
