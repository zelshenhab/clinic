import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../entities/medical_service.dart';
import '../entities/service_detail.dart';

abstract interface class ServiceRepository {
  Future<CatalogPage<MedicalService>> list(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  });
  Future<ServiceDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  });
}
