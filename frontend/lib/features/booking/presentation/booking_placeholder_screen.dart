import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/features/services/presentation/services_providers.dart';

/// Stand-in for the booking flow, which is built in the booking-experience change. It
/// proves the Book button opens the right place for the right service.
class BookingPlaceholderScreen extends ConsumerWidget {
  const BookingPlaceholderScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(serviceDetailProvider(serviceId)).value?.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Book a service')),
      body: SafeArea(
        child: MaxContentWidth(
          child: EmptyView(
            title: name == null ? 'Booking' : 'Booking: $name',
            message: 'Choosing a date and time arrives in the next update.',
            icon: Icons.event_available_outlined,
          ),
        ),
      ),
    );
  }
}
