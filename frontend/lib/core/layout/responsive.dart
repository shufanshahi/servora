import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// Width breakpoints (logical pixels) following Material window size classes.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// Widest a column of reading content should become.
  static const double maxContentWidth = 640;
}

/// Centers [child] and limits its width so content stays readable on tablets and in
/// landscape, while filling the screen on phones.
class MaxContentWidth extends StatelessWidget {
  const MaxContentWidth({
    required this.child,
    super.key,
    this.maxWidth = Breakpoints.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Number of grid columns that fit when each tile wants at least [minTileWidth].
int gridColumnsFor(
  double availableWidth, {
  double minTileWidth = 280,
  double spacing = AppSpacing.md,
}) {
  if (availableWidth <= 0) return 1;
  final columns = ((availableWidth + spacing) / (minTileWidth + spacing))
      .floor();
  return math.max(1, columns);
}

/// A scrollable grid that is a single column on phones and adds columns as the
/// screen widens, instead of stretching one tile across a tablet.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    super.key,
    this.minTileWidth = 280,
    this.spacing = AppSpacing.md,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.controller,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = padding.resolve(Directionality.of(context));
        final inner = constraints.maxWidth - resolved.horizontal;
        final columns = gridColumnsFor(
          inner,
          minTileWidth: minTileWidth,
          spacing: spacing,
        );

        // One column is a plain list so tiles can be any height (text can grow
        // with the user's font size without overflowing).
        if (columns == 1) {
          return ListView.separated(
            controller: controller,
            padding: padding,
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
            itemBuilder: (_, index) => children[index],
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final slice = children.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) SizedBox(width: spacing),
                    Expanded(
                      child: i < slice.length ? slice[i] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          controller: controller,
          padding: padding,
          itemCount: rows.length,
          separatorBuilder: (_, _) => SizedBox(height: spacing),
          itemBuilder: (_, index) => rows[index],
        );
      },
    );
  }
}
