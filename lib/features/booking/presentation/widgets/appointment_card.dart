import 'package:material_ui/material_ui.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// Hero tag for a booking's picture, shared by its card and its detail page. Keyed by
/// the booking (not the service), since one service can be booked many times.
String appointmentHeroTag(String appointmentId) =>
    serviceHeroTag(appointmentId, scope: 'appointment');

/// One row of My Bookings: picture, service, when, and the status.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    required this.appointment,
    required this.onTap,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when =
        '${formatDate(appointment.startsAt)}, '
        '${formatTime(appointment.startsAt)}';
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.inkMuted,
    );
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      semanticLabel:
          '${appointment.service.name}, $when, ${appointment.status.label}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ServiceImage(
                url: appointment.service.imageUrl,
                semanticLabel: appointment.service.name,
                aspectRatio: 0.92,
                heroTag: appointmentHeroTag(appointment.id),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.service.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.event_rounded,
                          size: 15,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(child: Text(when, style: muted)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  StatusBadge(status: appointment.status),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
