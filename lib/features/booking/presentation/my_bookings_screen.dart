import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/motion.dart';
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
      child: SafeArea(
        bottom: false,
        child: MaxContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.md,
                  AppSpacing.screenGutter,
                  AppSpacing.md,
                ),
                child: FadeSlideIn(
                  offset: const Offset(0, -12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Decorative, and dropped when text is very large.
                      if (MediaQuery.textScalerOf(context).scale(1) < 2) ...[
                        const Eyebrow('Your schedule'),
                        const SizedBox(height: 2),
                      ],
                      Semantics(
                        container: true,
                        header: true,
                        // Capped, so with very large text the tabs and list
                        // keep their room.
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.6,
                          child: Text(
                            'My Bookings',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // A segmented control: the selected tab slides as an ink pill.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Previous'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
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
                      icon: Icons.event_available_outlined,
                    )
                  : const EmptyView(
                      title: 'No previous bookings',
                      message: 'Completed and cancelled bookings appear here.',
                      icon: Icons.history_rounded,
                    ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.xl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm + 4),
              itemBuilder: (context, index) {
                final appointment = items[index];
                return FadeSlideIn.staggered(
                  index: index,
                  child: AppointmentCard(
                    appointment: appointment,
                    onTap: () => unawaited(
                      context.push(
                        AppRoutes.bookingDetail(appointment.id),
                        extra: appointment,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
