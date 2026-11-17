import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
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
