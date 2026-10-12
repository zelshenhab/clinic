import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../entities/specialty.dart';
import '../entities/specialty_detail.dart';

abstract interface class SpecialtyRepository {
  Future<CatalogPage<Specialty>> list(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  });
  Future<SpecialtyDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  });
}
