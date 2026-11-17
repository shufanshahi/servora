import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// Creates the [ImageProvider] used to load a service picture. Production uses
/// `cached_network_image` (pictures are kept on disk). Tests replace it with an
/// in-memory image, or a failing one, because the real thing needs platform plugins.
typedef ServiceImageProviderFactory = ImageProvider Function(String url);

final serviceImageProviderFactoryProvider =
    Provider<ServiceImageProviderFactory>(
      (ref) =>
          (url) => CachedNetworkImageProvider(url),
    );

/// A service picture in a fixed-shape box.
///
/// The box has its size before the picture arrives, so nothing around it moves while
/// loading. A neutral placeholder shows until the picture is ready and in its place
/// if the service has no picture or it fails to load.
class ServiceImage extends ConsumerWidget {
  const ServiceImage({
    required this.url,
    required this.semanticLabel,
    super.key,
    this.aspectRatio = 4 / 3,
  });

  final String? url;

  /// Spoken description, normally the service name.
  final String semanticLabel;
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = url;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: address == null || address.isEmpty
          ? const _ImagePlaceholder()
          : Image(
              image: ref.watch(serviceImageProviderFactoryProvider)(address),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: semanticLabel,
              // Until the first frame is ready, show the placeholder.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return const _ImagePlaceholder();
              },
              errorBuilder: (context, error, stackTrace) =>
                  const _ImagePlaceholder(failed: true),
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
        child: Center(
          child: Icon(
            failed ? Icons.broken_image_outlined : Icons.spa_outlined,
            size: AppSpacing.xl,
            color: scheme.outline,
          ),
        ),
      ),
    );
  }
}
