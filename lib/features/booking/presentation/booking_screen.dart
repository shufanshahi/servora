import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:intl/intl.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/services_providers.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

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
    final controller = ref.read(
      bookingControllerProvider(widget.serviceId).notifier,
    );
    final today = dateOnly(ref.read(nowProvider)());

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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.sm,
                AppSpacing.screenGutter,
                AppSpacing.xl,
              ),
              children: [
                FadeSlideIn(child: _ServiceHeader(service: svc)),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepHeader(
                        step: 1,
                        title: 'Date',
                        trailing: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.gold.withValues(
                              alpha: 0.14,
                            ),
                            foregroundColor: const Color(0xFF7D5E2E),
                          ),
                          tooltip: 'Choose a date from the calendar',
                          onPressed: booking.isSubmitting
                              ? null
                              : () => unawaited(_pickDate(booking)),
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatDate(booking.date),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DayStrip(
                        first: today,
                        selected: booking.date,
                        enabled: !booking.isSubmitting,
                        onSelect: controller.selectDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _StepHeader(step: 2, title: 'Time'),
                      const SizedBox(height: AppSpacing.md),
                      _Slots(
                        availability: availability,
                        selected: booking.slot,
                        enabled: !booking.isSubmitting,
                        onSelect: controller.selectSlot,
                        onRetry: () =>
                            ref.invalidate(availabilityProvider(query)),
                      ),
                    ],
                  ),
                ),
                if (booking.message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  MessageBanner(message: booking.message!),
                ],
                // The summary slides open once a time is chosen.
                AnimatedSize(
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : AppMotion.medium,
                  curve: AppMotion.emphasized,
                  alignment: Alignment.topCenter,
                  child: booking.slot == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xl),
                          child: _Summary(
                            service: svc,
                            date: booking.date,
                            slot: booking.slot!,
                            timeZone: availability.value?.timeZone ?? '',
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _StepHeader(step: 3, title: 'Anything to add?'),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _note,
                  enabled: !booking.isSubmitting,
                  maxLength: _noteLimit,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Anything the provider should know',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _ConfirmBar(
        isSubmitting: booking.isSubmitting,
        // Nothing to confirm until a time is chosen.
        onConfirm: booking.slot == null ? null : () => unawaited(_submit()),
      ),
    );
  }
}

/// The service being booked, as a compact card.
class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ServiceImage(
                url: service.imageUrl,
                semanticLabel: service.name,
                aspectRatio: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(service.category),
                const SizedBox(height: 2),
                Semantics(
                  container: true,
                  header: true,
                  child: Text(service.name, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(service.durationMinutes)} · '
                  '${formatPrice(service.price)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "1  Date" style heading for a step of the form.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, this.trailing});

  final int step;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
            ),
            child: Text(
              '$step',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 20),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The next days as a scrolling row of tiles, for picking a date with one tap. The
/// calendar button above covers the rest of the booking window.
class _DayStrip extends StatefulWidget {
  const _DayStrip({
    required this.first,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  static const days = 14;

  final DateTime first;
  final DateTime selected;
  final bool enabled;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  final _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _DayStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // A date chosen in the calendar may be off to the side: bring it into view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _selectedKey.currentContext;
        if (target == null || !mounted) return;
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.5,
            duration: reduceMotion(context) ? Duration.zero : AppMotion.medium,
            curve: AppMotion.standard,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = DateFormat('EEE', 'en_US');
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);

    return SizedBox(
      height: 76 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _DayStrip.days,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final day = DateTime(
            widget.first.year,
            widget.first.month,
            widget.first.day + index,
          );
          final selected = day == widget.selected;
          return Semantics(
            key: selected ? _selectedKey : null,
            button: true,
            selected: selected,
            label: formatDate(day),
            excludeSemantics: true,
            child: PressableScale(
              enabled: widget.enabled,
              child: GestureDetector(
                onTap: widget.enabled ? () => widget.onSelect(day) : null,
                child: AnimatedContainer(
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  width: 58 * scale,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md + 2),
                    border: Border.all(
                      color: selected ? AppColors.ink : AppColors.outline,
                    ),
                    boxShadow: selected ? AppShadows.lifted : const [],
                  ),
                  // One text, two lines, so the strip never reads as a bare number.
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${index == 0 ? 'Today' : weekday.format(day)}\n',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.4,
                            color: selected
                                ? AppColors.goldLight
                                : AppColors.inkMuted,
                          ),
                        ),
                        TextSpan(
                          text: '${day.day}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The always-visible bar with the confirm action.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.isSubmitting, required this.onConfirm});

  final bool isSubmitting;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: MaxContentWidth(
          fillHeight: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.md,
              AppSpacing.screenGutter,
              AppSpacing.md,
            ),
            child: AppButton(
              label: 'Confirm booking',
              icon: Icons.check_rounded,
              isLoading: isSubmitting,
              onPressed: onConfirm,
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
        // Grouped by part of the day, from the hour in each label ("09:30").
        final groups = <String, List<Slot>>{};
        for (final slot in data.slots) {
          final hour = int.tryParse(slot.label.split(':').first) ?? 0;
          final part = hour < 12
              ? 'Morning'
              : hour < 17
              ? 'Afternoon'
              : 'Evening';
          (groups[part] ??= []).add(slot);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final MapEntry(key: part, value: slots) in groups.entries) ...[
              Row(
                children: [
                  Icon(
                    part == 'Morning'
                        ? Icons.wb_twilight_rounded
                        : part == 'Afternoon'
                        ? Icons.wb_sunny_outlined
                        : Icons.nights_stay_outlined,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    part,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final slot in slots)
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
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
                    'Times are shown in ${data.timeZone}. Greyed-out times are taken.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
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
    required this.timeZone,
  });

  final Service service;
  final DateTime date;
  final Slot slot;

  /// The zone the slot's label is in.
  final String timeZone;

  String get _localLabel {
    final local = DateTime.parse(slot.startsAt).toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = Colors.white.withValues(alpha: 0.65);
    Widget row(String label, String value, {bool emphasis = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.md,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          Text(
            value,
            style:
                (emphasis
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: emphasis ? AppColors.goldLight : Colors.white,
                      fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
                    ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: 'Booking summary',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lifted,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.goldLight,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: AppSpacing.xs),
            row('Service', service.name),
            row('Date', formatDate(date)),
            row('Time', '${slot.label} $timeZone'.trim()),
            // Said plainly when the phone is in another zone, so nobody is surprised by
            // the time on the confirmation and in My Bookings (which use the phone's zone).
            if (_localLabel != slot.label)
              row('Your time', formatTime(DateTime.parse(slot.startsAt))),
            row('Duration', formatDuration(service.durationMinutes)),
            const SizedBox(height: AppSpacing.xs),
            Divider(color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: AppSpacing.xs),
            row('Price', formatPrice(service.price), emphasis: true),
          ],
        ),
      ),
    );
  }
}
