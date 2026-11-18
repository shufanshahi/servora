import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/core/network/page_meta.dart';
import 'package:servora/core/network/providers.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/domain/service_filter.dart';
import 'package:servora/features/services/domain/service_page.dart';

/// Reads the public service catalogue. Throws [AppFailure] for every kind of failure.
class ServicesRepository {
  ServicesRepository(this._api);

  final ApiClient _api;

  /// The query parameters for a list request. Blank values are left out entirely.
  static Map<String, dynamic> queryFor({
    ServiceFilter filter = const ServiceFilter(),
    int page = 1,
    int limit = 20,
    bool? featured,
  }) {
    final text = filter.query.trim();
    return {
      if (text.isNotEmpty) 'q': text,
      if (filter.category != null) 'category': filter.category,
      'featured': ?featured?.toString(),
      'page': page,
      'limit': limit,
    };
  }

  Future<ServicePage> list({
    ServiceFilter filter = const ServiceFilter(),
    int page = 1,
    int limit = 20,
    bool? featured,
  }) async {
    final response = await _api.get(
      '/services',
      query: queryFor(
        filter: filter,
        page: page,
        limit: limit,
        featured: featured,
      ),
      // The catalogue is public, so a missing or expired token must never matter here.
      authenticated: false,
    );
    try {
      final meta = response.meta;
      if (meta == null) throw const FormatException('missing meta');
      return ServicePage(
        items: [
          for (final item in response.data as List<dynamic>)
            Service.fromJson(item as Map<String, dynamic>),
        ],
        meta: PageMeta(page: meta.page, limit: meta.limit, total: meta.total),
      );
    } on Object {
      throw const UnknownFailure();
    }
  }

  Future<Service> get(String id) async {
    final response = await _api.get(
      '/services/${Uri.encodeComponent(id)}',
      authenticated: false,
    );
    try {
      return Service.fromJson(response.data as Map<String, dynamic>);
    } on Object {
      throw const UnknownFailure();
    }
  }
}

final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.watch(apiClientProvider)),
);
