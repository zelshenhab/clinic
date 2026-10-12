class CatalogPage<T> {
  const CatalogPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
    this.categories = const {},
  });
  final List<T> items;
  final int page, total;
  final bool hasMore;
  final Map<String, Map<String, String>> categories;
}
