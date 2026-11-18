import 'package:material_ui/material_ui.dart';
import 'package:servora/core/widgets/loading_view.dart';

/// The splash screen shown while the saved session is being restored.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: LoadingView(message: 'Starting Servora'));
}
