import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
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
        title: const Text('Cancel this booking?'),
        content: const Text('The time will be released for other customers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
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

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SafeArea(
        child: MaxContentWidth(
          child: appointment != null
              ? _Content(
                  appointment: appointment,
                  cancelling: _cancelling,
                  onCancel: () => unawaited(_cancel()),
                )
              : failure != null
              ? ErrorView(
                  message: userMessageFor(failure),
                  onRetry: gone
                      ? null
                      : () => ref.invalidate(
                          appointmentDetailProvider(widget.appointmentId),
                        ),
                )
              : const LoadingView(message: 'Loading booking'),
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
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpacing.xs,
        spacing: AppSpacing.md,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value,
        ],
      ),
    );
    Widget text(String value) => Text(
      value,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final note = appointment.note;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ServiceImage(
            url: appointment.service.imageUrl,
            semanticLabel: appointment.service.name,
            aspectRatio: 16 / 9,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            appointment.service.name,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          appointment.service.category,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row('Status', StatusBadge(status: appointment.status)),
                row('Date', text(formatDate(appointment.startsAt))),
                row(
                  'Time',
                  text(
                    formatTimeRange(appointment.startsAt, appointment.endsAt),
                  ),
                ),
                row(
                  'Duration',
                  text(formatDuration(appointment.service.durationMinutes)),
                ),
                row('Price', text(formatPrice(appointment.price))),
                if (note != null && note.isNotEmpty) row('Note', text(note)),
                if (appointment.cancelledAt != null)
                  row('Cancelled', text(formatDate(appointment.cancelledAt!))),
              ],
            ),
          ),
        ),
        // Only pending bookings can be cancelled.
        if (appointment.canCancel) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Cancel booking',
            variant: AppButtonVariant.secondary,
            icon: Icons.cancel_outlined,
            isLoading: cancelling,
            onPressed: onCancel,
          ),
        ],
      ],
    );
  }
}
