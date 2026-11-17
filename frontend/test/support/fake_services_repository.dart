import 'package:servora/core/network/page_meta.dart';
import 'package:servora/features/services/data/services_repository.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/domain/service_filter.dart';
import 'package:servora/features/services/domain/service_page.dart';

/// One recorded call to [FakeServicesRepository.list].
typedef ListCall = ({
  ServiceFilter filter,
  int page,
  int limit,
  bool? featured,
});

/// A scriptable [ServicesRepository]. By default it behaves like a small real catalogue:
/// it filters [catalogue] by text and category, pages it, and honours `featured`.
/// Set [onList] or [onGet] to take full control (for example to hold a request open
/// with a Completer, or to throw an AppFailure).
class FakeServicesRepository implements ServicesRepository {
  FakeServicesRepository(this.catalogue);

  final List<Service> catalogue;

  Future<ServicePage> Function(ListCall call)? onList;
  Future<Service> Function(String id)? onGet;

  final List<ListCall> listCalls = [];
  final List<String> getCalls = [];

  /// Calls that were not the featured or category-discovery lookups.
  List<ListCall> get listRequests =>
      listCalls.where((c) => c.featured != true && c.limit != 50).toList();

  @override
  Future<ServicePage> list({
    ServiceFilter filter = const ServiceFilter(),
    int page = 1,
    int limit = 20,
    bool? featured,
  }) {
    final call = (filter: filter, page: page, limit: limit, featured: featured);
    listCalls.add(call);
    final handler = onList;
    if (handler != null) return handler(call);
    return Future.value(_defaultPage(call));
  }

  @override
  Future<Service> get(String id) {
    getCalls.add(id);
    final handler = onGet;
    if (handler != null) return handler(id);
    final match = catalogue.where((s) => s.id == id);
    if (match.isEmpty) {
      throw StateError('FakeServicesRepository: no service $id');
    }
    return Future.value(match.first);
  }

  ServicePage _defaultPage(ListCall call) {
    final text = call.filter.query.trim().toLowerCase();
    final matches = catalogue.where((s) {
      if (call.featured == true && !s.isFeatured) return false;
      if (call.filter.category != null && s.category != call.filter.category) {
        return false;
      }
      if (text.isNotEmpty &&
          !s.name.toLowerCase().contains(text) &&
          !s.description.toLowerCase().contains(text)) {
        return false;
      }
      return true;
    }).toList();
    final start = (call.page - 1) * call.limit;
    final items = start >= matches.length
        ? <Service>[]
        : matches.sublist(start, (start + call.limit).clamp(0, matches.length));
    return ServicePage(
      items: items,
      meta: PageMeta(page: call.page, limit: call.limit, total: matches.length),
    );
  }

  /// A page built by hand, for scripted [onList] handlers.
  static ServicePage pageOf(
    List<Service> items, {
    int? total,
    int page = 1,
    int limit = 20,
  }) => ServicePage(
    items: items,
    meta: PageMeta(page: page, limit: limit, total: total ?? items.length),
  );
}
