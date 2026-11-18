import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';

/// Maps an [AsyncValue] onto the shared loading, empty, error and success views so
/// every screen handles the four data states the same way.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    super.key,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  final AsyncValue<T> value;

  /// Builds the success state.
  final Widget Function(T data) data;

  /// Called by the error view's retry button. Null hides the button.
  final VoidCallback? onRetry;

  /// When it returns true for the loaded data, [empty] is shown instead of [data].
  final bool Function(T data)? isEmpty;

  /// Widget for the empty state (defaults to a generic [EmptyView]).
  final Widget? empty;

  /// Widget for the loading state (defaults to [LoadingView]).
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const LoadingView(),
      error: (error, _) =>
          ErrorView(message: userMessageFor(error), onRetry: onRetry),
      data: (loaded) {
        if (isEmpty?.call(loaded) ?? false) {
          return empty ?? const EmptyView(title: 'Nothing here yet');
        }
        return data(loaded);
      },
    );
  }
}
