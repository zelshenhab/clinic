import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../repositories/doctor_repository.dart';
import '../entities/doctor.dart';
import '../entities/doctor_detail.dart';

class LoadDoctors {
  LoadDoctors(this.repository);
  final DoctorRepository repository;
  Future<CatalogPage<Doctor>> call(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) => repository.list(clinicId, token, query: query);
  Future<DoctorDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  }) => repository.detail(clinicId, id, token, locale: locale);
}
