import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/detail_row.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// Shown right after a booking succeeds. It is built from the appointment the API
/// returned, so it needs no further request.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({required this.appointment, super.key});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: MaxContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.md,
              AppSpacing.screenGutter,
              AppSpacing.xl,
            ),
            children: [
              const Center(child: SuccessMark()),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        'Your booking is in',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "It's pending and will be confirmed shortly.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 480),
                child: _Ticket(appointment: appointment),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Times are shown in your phone's time zone.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      // The next steps stay in reach however long the receipt is.
      bottomNavigationBar: SafeArea(
        top: false,
        child: MaxContentWidth(
          fillHeight: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.sm,
              AppSpacing.screenGutter,
              AppSpacing.md,
            ),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'View my bookings',
                    icon: Icons.calendar_month_outlined,
                    onPressed: () => context.go(AppRoutes.bookings),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Back to home',
                    variant: AppButtonVariant.text,
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The booking as a ticket: the service on top, the tear line, then the details.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      shadow: AppShadows.lifted,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ServiceImage(
                    url: appointment.service.imageUrl,
                    semanticLabel: appointment.service.name,
                    aspectRatio: 1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    Text(
                      appointment.service.name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const TicketDivider(),
          DetailRow.text(
            icon: Icons.event_rounded,
            label: 'Date',
            value: formatDate(appointment.startsAt),
          ),
          DetailRow.text(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: formatTimeRange(appointment.startsAt, appointment.endsAt),
          ),
          DetailRow(
            icon: Icons.payments_outlined,
            label: 'Price',
            value: Text(
              formatPrice(appointment.price),
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          DetailRow(
            icon: Icons.flag_outlined,
            label: 'Status',
            value: StatusBadge(status: appointment.status),
          ),
        ],
      ),
    );
  }
}

/// A celebratory check mark: a ring draws itself, the tick strokes in, and a ring of
/// gold sparks bursts outwards. Plays once; with reduced motion it is simply shown.
class SuccessMark extends StatefulWidget {
  const SuccessMark({super.key, this.size = 112});

  final double size;

  @override
  State<SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<SuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
    final box = widget.size * 1.7;
    return ExcludeSemantics(
      child: SizedBox(
        width: box,
        height: box,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) =>
              CustomPaint(painter: _SuccessPainter(_controller.value)),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.t);

  final double t;

  double _phase(
    double start,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 1.7 / 2;

    // Soft halo and filled disc, growing in.
    final grow = _phase(0, 0.45, Curves.easeOutBack);
    canvas.drawCircle(
      center,
      radius * 1.25 * grow,
      Paint()..color = AppColors.primary.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      center,
      radius * grow,
      Paint()
        ..shader = AppColors.heroGradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        ),
    );

    // The gold ring, drawing itself round.
    final ring = _phase(0.1, 0.6);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      -math.pi / 2,
      2 * math.pi * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold,
    );

    // The tick, stroked from left to right.
    final tick = _phase(0.35, 0.75);
    if (tick > 0) {
      final a = center + Offset(-radius * 0.36, radius * 0.02);
      final b = center + Offset(-radius * 0.1, radius * 0.28);
      final c = center + Offset(radius * 0.38, -radius * 0.24);
      final first = (a - b).distance;
      final total = first + (c - b).distance;
      final drawn = total * tick;
      final path = Path()..moveTo(a.dx, a.dy);
      if (drawn <= first) {
        final p = Offset.lerp(a, b, drawn / first)!;
        path.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(b.dx, b.dy);
        final p = Offset.lerp(b, c, (drawn - first) / (total - first))!;
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.13
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }

    // Gold sparks flying outwards and fading.
    final burst = _phase(0.45, 1);
    if (burst > 0 && burst < 1) {
      const count = 12;
      for (var i = 0; i < count; i++) {
        final angle = (i / count) * 2 * math.pi + 0.2;
        final distance = radius * (1.15 + 0.5 * burst);
        final p = center + Offset(math.cos(angle), math.sin(angle)) * distance;
        canvas.drawCircle(
          p,
          (i.isEven ? 3.2 : 2.2) * (1 - burst),
          Paint()
            ..color = (i.isEven ? AppColors.gold : AppColors.primary)
                .withValues(alpha: 1 - burst),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter old) => old.t != t;
}
