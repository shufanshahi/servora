import 'package:servora/core/network/page_meta.dart';

/// Successful API response with the envelope already removed: [data] is the
/// payload and [meta] is present on list endpoints.
class ApiResponse {
  const ApiResponse({required this.data, this.meta});

  final dynamic data;
  final PageMeta? meta;
}
