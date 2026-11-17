import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/services_providers.dart';

/// Choose a day and a time for one service, review the summary and book it.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  static const _noteLimit = 500;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BookingState booking) async {
    final today = dateOnly(ref.read(nowProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: booking.date,
      firstDate: today,
      lastDate: today.add(const Duration(days: bookingHorizonDays)),
      helpText: 'Choose a date',
    );
    if (picked == null) return;
    ref
        .read(bookingControllerProvider(widget.serviceId).notifier)
        .selectDate(picked);
  }

  Future<void> _submit() async {
    final appointment = await ref
        .read(bookingControllerProvider(widget.serviceId).notifier)
        .submit(note: _note.text);
    if (appointment == null || !mounted) return;
    // Replaces this screen, so Back from the confirmation does not return to a form
    // for a booking that already exists.
    context.pushReplacement(AppRoutes.bookingConfirmation, extra: appointment);
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingControllerProvider(widget.serviceId));
    final service = ref.watch(serviceDetailProvider(widget.serviceId));
    final query = (serviceId: widget.serviceId, date: dateKey(booking.date));
    final availability = ref.watch(availabilityProvider(query));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Book a service')),
      body: SafeArea(
        child: MaxContentWidth(
          child: service.when(
            loading: () => const LoadingView(message: 'Loading service'),
            error: (error, _) => ErrorView(
              message: userMessageFor(error),
              onRetry: error is NotFoundFailure
                  ? null
                  : () =>
                        ref.invalidate(serviceDetailProvider(widget.serviceId)),
            ),
            data: (svc) => ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Semantics(
                  header: true,
                  child: Text(svc.name, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatDuration(svc.durationMinutes)} · ${formatPrice(svc.price)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('Date', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: booking.isSubmitting
                        ? null
                        : () => unawaited(_pickDate(booking)),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(formatDate(booking.date)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('Time', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Slots(
                  availability: availability,
                  selected: booking.slot,
                  enabled: !booking.isSubmitting,
                  onSelect: ref
                      .read(
                        bookingControllerProvider(widget.serviceId).notifier,
                      )
                      .selectSlot,
                  onRetry: () => ref.invalidate(availabilityProvider(query)),
                ),
                if (booking.message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  MessageBanner(message: booking.message!),
                ],
                if (booking.slot != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Summary(
                    service: svc,
                    date: booking.date,
                    slot: booking.slot!,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _note,
                  enabled: !booking.isSubmitting,
                  maxLength: _noteLimit,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Anything the provider should know',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: MaxContentWidth(
            fillHeight: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Confirm booking',
                isLoading: booking.isSubmitting,
                // Nothing to confirm until a time is chosen.
                onPressed: booking.slot == null
                    ? null
                    : () => unawaited(_submit()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slots extends StatelessWidget {
  const _Slots({
    required this.availability,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onRetry,
  });

  final AsyncValue<Availability> availability;
  final Slot? selected;
  final bool enabled;
  final void Function(Slot) onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return availability.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LoadingView(message: 'Loading times'),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: MessageBanner(message: userMessageFor(error), onRetry: onRetry),
      ),
      data: (data) {
        if (data.slots.isEmpty || !data.hasAvailableSlot) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: MessageBanner(
              message: 'No times are available on this day. Try another date.',
              tone: BannerTone.info,
            ),
          );
        }
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final slot in data.slots)
                  ChoiceChip(
                    // Taken times stay visible but cannot be chosen.
                    label: Text(slot.label),
                    selected: selected == slot,
                    onSelected: slot.available && enabled
                        ? (_) => onSelect(slot)
                        : null,
                    tooltip: slot.available
                        ? 'Start at ${slot.label}'
                        : '${slot.label} is not available',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Times are shown in ${data.timeZone}. Greyed-out times are taken.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.service,
    required this.date,
    required this.slot,
  });

  final Service service;
  final DateTime date;
  final Slot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: 'Booking summary',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            row('Service', service.name),
            row('Date', formatDate(date)),
            row('Time', slot.label),
            row('Duration', formatDuration(service.durationMinutes)),
            row('Price', formatPrice(service.price)),
          ],
        ),
      ),
    );
  }
}
