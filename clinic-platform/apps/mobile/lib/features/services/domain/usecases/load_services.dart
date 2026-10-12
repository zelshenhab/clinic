import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../repositories/service_repository.dart';
import '../entities/medical_service.dart';
import '../entities/service_detail.dart';

class LoadServices {
  LoadServices(this.repository);
  final ServiceRepository repository;
  Future<CatalogPage<MedicalService>> call(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) => repository.list(clinicId, token, query: query);
  Future<ServiceDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  }) => repository.detail(clinicId, id, token, locale: locale);
}
