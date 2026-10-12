import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../repositories/specialty_repository.dart';
import '../entities/specialty.dart';
import '../entities/specialty_detail.dart';

class LoadSpecialties {
  LoadSpecialties(this.repository);
  final SpecialtyRepository repository;
  Future<CatalogPage<Specialty>> call(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) => repository.list(clinicId, token, query: query);
  Future<SpecialtyDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  }) => repository.detail(clinicId, id, token, locale: locale);
}
