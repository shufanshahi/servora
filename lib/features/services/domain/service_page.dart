import 'package:servora/core/network/page_meta.dart';
import 'package:servora/features/services/domain/service.dart';

/// One page of services plus the paging details.
class ServicePage {
  const ServicePage({required this.items, required this.meta});

  final List<Service> items;
  final PageMeta meta;
}
