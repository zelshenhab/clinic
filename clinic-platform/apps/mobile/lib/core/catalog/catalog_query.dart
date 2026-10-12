class CatalogQuery {
  const CatalogQuery({
    this.search = '',
    this.specialtyId,
    this.serviceId,
    this.doctorId,
    this.category,
    this.sort = 'featured',
    this.locale = 'ru',
    this.page = 1,
    this.limit = 12,
  });
  final String search, sort, locale;
  final String? specialtyId, serviceId, doctorId, category;
  final int page, limit;
  CatalogQuery copy({
    String? search,
    String? specialtyId,
    String? serviceId,
    String? doctorId,
    String? category,
    String? sort,
    String? locale,
    int? page,
    bool clearSpecialty = false,
    bool clearCategory = false,
  }) => CatalogQuery(
    search: search ?? this.search,
    specialtyId: clearSpecialty ? null : specialtyId ?? this.specialtyId,
    serviceId: serviceId ?? this.serviceId,
    doctorId: doctorId ?? this.doctorId,
    category: clearCategory ? null : category ?? this.category,
    sort: sort ?? this.sort,
    locale: locale ?? this.locale,
    page: page ?? this.page,
    limit: limit,
  );
  Map<String, String> get parameters => {
    'search': search,
    'sort': sort,
    'locale': locale,
    'page': '$page',
    'limit': '$limit',
    'specialtyId': ?specialtyId,
    'serviceId': ?serviceId,
    'doctorId': ?doctorId,
    'category': ?category,
  };
  String path(String base) =>
      Uri(path: base, queryParameters: parameters).toString();
}
