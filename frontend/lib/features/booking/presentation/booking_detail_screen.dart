import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/detail_row.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/glass.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/booking/presentation/widgets/appointment_card.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// Everything about one booking, with cancel for pending ones.
///
/// [initial] is the copy the user tapped in the list; it shows at once and the screen
/// refreshes it from the API.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({
    required this.appointmentId,
    super.key,
    this.initial,
  });

  final String appointmentId;
  final Appointment? initial;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_busy_rounded, color: AppColors.error),
        title: const Text('Cancel this booking?'),
        content: const Text('The time will be released for other customers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final outcome = await cancelAppointment(ref, widget.appointmentId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    final text = switch (outcome) {
      CancelSucceeded() => 'Booking cancelled',
      CancelFailed(:final message) => message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(appointmentDetailProvider(widget.appointmentId));
    final failure = detail.hasError && !detail.isLoading ? detail.error : null;
    final gone = failure is NotFoundFailure;
    final appointment = gone ? null : (detail.value ?? widget.initial);

    final hasPhoto = appointment != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: hasPhoto ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: hasPhoto,
        appBar: AppBar(
          backgroundColor: hasPhoto ? Colors.transparent : null,
          automaticallyImplyLeading: false,
          leading: Navigator.of(context).canPop()
              ? Center(
                  child: GlassCircle(
                    dark: !hasPhoto,
                    child: const BackButton(color: Colors.white),
                  ),
                )
              : null,
          title: hasPhoto ? null : const Text('Booking details'),
        ),
        body: MaxContentWidth(
          child: appointment != null
              ? _Content(
                  appointment: appointment,
                  cancelling: _cancelling,
                  onCancel: () => unawaited(_cancel()),
                )
              : SafeArea(
                  child: failure != null
                      ? ErrorView(
                          message: userMessageFor(failure),
                          onRetry: gone
                              ? null
                              : () => ref.invalidate(
                                  appointmentDetailProvider(
                                    widget.appointmentId,
                                  ),
                                ),
                        )
                      : const LoadingView(message: 'Loading booking'),
                ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.appointment,
    required this.cancelling,
    required this.onCancel,
  });

  final Appointment appointment;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = appointment.note;
    final headerHeight = (MediaQuery.sizeOf(context).height * 0.36).clamp(
      200.0,
      340.0,
    );
    const overlap = 28.0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: headerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ServiceImage(
                url: appointment.service.imageUrl,
                semanticLabel: appointment.service.name,
                aspectRatio: null,
                heroTag: appointmentHeroTag(appointment.id),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0x8C000000), Color(0x00000000)],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: overlap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(overlap),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      child: Text(
                        appointment.service.category,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        appointment.service.name,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'Status',
                        value: StatusBadge(status: appointment.status),
                      ),
                      DetailRow.text(
                        icon: Icons.event_rounded,
                        label: 'Date',
                        value: formatDate(appointment.startsAt),
                      ),
                      DetailRow.text(
                        icon: Icons.schedule_rounded,
                        label: 'Time',
                        value: formatTimeRange(
                          appointment.startsAt,
                          appointment.endsAt,
                        ),
                      ),
                      DetailRow.text(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'Duration',
                        value: formatDuration(
                          appointment.service.durationMinutes,
                        ),
                      ),
                      const TicketDivider(),
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
                      if (note != null && note.isNotEmpty)
                        DetailRow.text(
                          icon: Icons.sticky_note_2_outlined,
                          label: 'Note',
                          value: note,
                        ),
                      if (appointment.cancelledAt != null)
                        DetailRow.text(
                          icon: Icons.event_busy_outlined,
                          label: 'Cancelled',
                          value: formatDate(appointment.cancelledAt!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.public_rounded,
                    size: 15,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      "Times are shown in your phone's time zone.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              // Only pending bookings can be cancelled.
              if (appointment.canCancel) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Cancel booking',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  isLoading: cancelling,
                  onPressed: onCancel,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
