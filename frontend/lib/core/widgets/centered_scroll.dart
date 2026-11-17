import 'package:material_ui/material_ui.dart';

/// Centers [child] in the available space, and lets it scroll when it is taller
/// than the space (small screens, landscape, large accessibility text). This keeps
/// empty, error and form screens free of overflow errors.
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
