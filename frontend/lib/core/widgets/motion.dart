import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// Whether the user asked the system to reduce motion. Every animation in the app
/// checks this and jumps straight to its end state when it is set.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades [child] in while sliding it up into place, once, when it first appears.
///
/// [delay] staggers a group: give the n-th item `AppMotion.stagger * n` (see
/// [FadeSlideIn.staggered]). The delay is part of the one animation (no timers), so
/// nothing is left running when the widget goes away.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.offset = const Offset(0, 24),
  });

  /// The [index]-th item of a list. The delay is capped so long lists don't keep the
  /// user waiting for items further down.
  factory FadeSlideIn.staggered({
    required int index,
    required Widget child,
    Key? key,
    Duration baseDelay = Duration.zero,
    Offset offset = const Offset(0, 24),
  }) => FadeSlideIn(
    key: key,
    delay: baseDelay + AppMotion.stagger * math.min(index, 8),
    offset: offset,
    child: child,
  );

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Where the child starts, relative to its final position, in logical pixels.
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: AppMotion.emphasized,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          // Screen readers get the content at once, not when the fade is done.
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: child,
          ),
        );
      },
    );
  }
}

/// Shrinks [child] slightly while a finger is on it, which makes cards and buttons
/// feel physical. It only listens to pointers and takes no part in gesture handling,
/// so taps still reach the [InkWell] or button inside.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    super.key,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// A soft highlight that sweeps across [child] to say "loading". Used on skeletons.
/// It stands still when the user prefers reduced motion.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final dx = _controller.value * 3 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx - 1, -0.3),
            end: Alignment(dx + 1, 0.3),
            colors: const [
              Color(0x00FFFFFF),
              Color(0x99FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Three dots that rise and fall in turn: "someone is typing".
class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key, this.color, this.size = 7});

  final Color? color;
  final double size;

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
              child: Transform.translate(
                offset: Offset(
                  0,
                  -widget.size *
                      0.8 *
                      math.max(
                        0,
                        math.sin((_controller.value - i * 0.15) * 2 * math.pi),
                      ),
                ),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha:
                          0.45 +
                          0.55 *
                              math.max(
                                0,
                                math.sin(
                                  (_controller.value - i * 0.15) * 2 * math.pi,
                                ),
                              ),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
