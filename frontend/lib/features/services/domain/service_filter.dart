/// What the user has asked the catalogue to show: a text search and/or one category.
///
/// A value object: two filters with the same fields are equal, which is how Riverpod
/// knows a filter really changed.
class ServiceFilter {
  const ServiceFilter({this.query = '', this.category});

  /// Text to look for in names and descriptions. Blank means "no search".
  final String query;

  /// Exact category, or null for all categories.
  final String? category;

  /// True when the filter changes nothing (no search text, no category).
  bool get isEmpty => query.trim().isEmpty && category == null;

  ServiceFilter withQuery(String value) =>
      ServiceFilter(query: value, category: category);

  ServiceFilter withCategory(String? value) =>
      ServiceFilter(query: query, category: value);

  @override
  bool operator ==(Object other) =>
      other is ServiceFilter &&
      other.query.trim() == query.trim() &&
      other.category == category;

  @override
  int get hashCode => Object.hash(query.trim(), category);

  @override
  String toString() => 'ServiceFilter(query: "$query", category: $category)';
}
