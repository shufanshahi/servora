import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/network/media_url.dart';
import 'package:servora/core/network/providers.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/motion.dart';

/// Creates the [ImageProvider] used to load a service picture. Production uses
/// `cached_network_image` (pictures are kept on disk). Tests replace it with an
/// in-memory image, or a failing one, because the real thing needs platform plugins.
typedef ServiceImageProviderFactory = ImageProvider Function(String url);

final serviceImageProviderFactoryProvider =
    Provider<ServiceImageProviderFactory>(
      (ref) =>
          (url) => CachedNetworkImageProvider(url),
    );

/// Hero tag shared by a service picture in a list and on its detail page, so the
/// picture flies from one to the other.
String serviceHeroTag(String serviceId, {String scope = 'list'}) =>
    'service-image-$scope-$serviceId';

/// A service picture in a fixed-shape box.
///
/// The box has its size before the picture arrives, so nothing around it moves while
/// loading. A soft branded placeholder shows until the picture is ready (it then fades
/// in) and stays in its place if the service has no picture or it fails to load.
class ServiceImage extends ConsumerWidget {
  const ServiceImage({
    required this.url,
    required this.semanticLabel,
    super.key,
    this.aspectRatio = 4 / 3,
    this.heroTag,
  });

  final String? url;

  /// Spoken description, normally the service name.
  final String semanticLabel;

  /// Null fills whatever box the parent gives (for example a collapsing header).
  final double? aspectRatio;

  /// When set, the picture takes part in a [Hero] flight with this tag.
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = url;
    final address = raw == null || raw.trim().isEmpty
        ? null
        : resolveMediaUrl(raw, ref.watch(appConfigProvider).apiBaseUrl);

    Widget picture = address == null
        ? const _ImagePlaceholder()
        : Image(
            image: ref.watch(serviceImageProviderFactoryProvider)(address),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            semanticLabel: semanticLabel,
            gaplessPlayback: true,
            // The placeholder sits underneath, and the picture fades in over it.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (frame == null) const _ImagePlaceholder(),
                  AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : AppMotion.medium,
                    curve: AppMotion.standard,
                    child: child,
                  ),
                ],
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                const _ImagePlaceholder(failed: true),
          );

    final tag = heroTag;
    if (tag != null) {
      picture = Hero(
        tag: tag,
        // During the flight the picture is drawn without its parent's rounded clip.
        // Its corners soften as it shrinks back into a card and sharpen as it grows
        // into a full-width header, so it never flashes square.
        flightShuttleBuilder: (context, animation, direction, from, to) =>
            AnimatedBuilder(
              animation: animation,
              child: (to.widget as Hero).child,
              builder: (context, child) => ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppRadius.md * (1 - animation.value),
                ),
                child: child,
              ),
            ),
        child: picture,
      );
    }

    final ratio = aspectRatio;
    return ratio == null
        ? picture
        : AspectRatio(aspectRatio: ratio, child: picture);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1ECE4), Color(0xFFE4DCCF)],
          ),
        ),
        child: Center(
          child: Icon(
            failed ? Icons.broken_image_outlined : Icons.spa_outlined,
            size: AppSpacing.xl,
            color: AppColors.gold.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
