import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';

/// Shown right after a booking succeeds. It is built from the appointment the API
/// returned, so it needs no further request.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({required this.appointment, super.key});

  final Appointment appointment;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: MaxContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const SizedBox(height: AppSpacing.md),
              Icon(
                Icons.check_circle,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  'Your booking is in',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "It's pending and will be confirmed shortly.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row('Service', text(appointment.service.name)),
                      row('Date', text(formatDate(appointment.startsAt))),
                      row(
                        'Time',
                        text(
                          formatTimeRange(
                            appointment.startsAt,
                            appointment.endsAt,
                          ),
                        ),
                      ),
                      row('Price', text(formatPrice(appointment.price))),
                      row('Status', StatusBadge(status: appointment.status)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Times are shown in your phone's time zone.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'View my bookings',
                icon: Icons.calendar_month_outlined,
                onPressed: () => context.go(AppRoutes.bookings),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Back to home',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
