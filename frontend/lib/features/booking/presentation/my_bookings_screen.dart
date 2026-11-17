import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/booking/presentation/widgets/appointment_card.dart';

/// The My Bookings tab: Upcoming and Previous.
class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: AppointmentScope.values.length,
      child: MaxContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  'My Bookings',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Upcoming'),
                Tab(text: 'Previous'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _BookingsTab(scope: AppointmentScope.upcoming),
                  _BookingsTab(scope: AppointmentScope.previous),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab({required this.scope});

  final AppointmentScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(appointmentsProvider(scope));

    Future<void> refresh() async {
      ref.invalidate(appointmentsProvider(scope));
      try {
        await ref.read(appointmentsProvider(scope).future);
      } on Object {
        // The failure is shown by the list itself.
      }
    }

    // Empty and error messages sit in a scrollable of their own, so pull to refresh
    // works on them too.
    Widget message(Widget child) => LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight, child: child)],
      ),
    );

    final failure = bookings.hasError && !bookings.isLoading
        ? bookings.error
        : null;
    final items = bookings.value;

    return RefreshIndicator(
      onRefresh: refresh,
      child: failure != null
          ? message(
              ErrorView(
                message: userMessageFor(failure),
                onRetry: () => ref.invalidate(appointmentsProvider(scope)),
              ),
            )
          : items == null
          // Just the spinner: with very large text the tab is too short for a caption.
          ? Center(
              child: Semantics(
                label: 'Loading bookings',
                liveRegion: true,
                child: const CircularProgressIndicator(),
              ),
            )
          : items.isEmpty
          ? message(
              scope == AppointmentScope.upcoming
                  ? const EmptyView(
                      title: 'No upcoming bookings',
                      message: 'Book a service and it will show up here.',
                      icon: Icons.calendar_month_outlined,
                    )
                  : const EmptyView(
                      title: 'No previous bookings',
                      message: 'Completed and cancelled bookings appear here.',
                      icon: Icons.history,
                    ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final appointment = items[index];
                return AppointmentCard(
                  appointment: appointment,
                  onTap: () => unawaited(
                    context.push(
                      AppRoutes.bookingDetail(appointment.id),
                      extra: appointment,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
