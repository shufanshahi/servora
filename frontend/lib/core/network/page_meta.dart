/// Pagination details returned with list responses.
class PageMeta {
  const PageMeta({
    required this.page,
    required this.limit,
    required this.total,
  });

  factory PageMeta.fromJson(Map<String, dynamic> json) {
    return PageMeta(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
    );
  }

  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;
}
