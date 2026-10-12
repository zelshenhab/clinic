import '../../../../core/network/api_client.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/medical_service.dart';
import '../../domain/entities/service_detail.dart';
import '../../domain/repositories/service_repository.dart';
import '../models/service_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../clinic_selection/data/models/clinic_model.dart';

class ApiServiceRepository implements ServiceRepository {
  ApiServiceRepository(this.api);
  final ApiClient api;
  @override
  Future<CatalogPage<MedicalService>> list(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) async => CatalogParser.page(
    await api.get(
      query.path('/clinics/$clinicId/services'),
      cancelToken: token,
    ),
    (row) => ServiceModel.parse(row, clinicId),
  );
  @override
  Future<ServiceDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  }) async {
    final data = await api.get(
      '/clinics/$clinicId/services/$id?locale=$locale',
      cancelToken: token,
    );
    return CatalogParser.safe(() {
      final row = CatalogParser.object(data);
      final clinic = ClinicModel.parse(row['clinic']);
      if (clinic.id != clinicId) throw const FormatException();
      return ServiceDetail(
        ServiceModel.parse(row, clinicId),
        clinic,
        CatalogParser.page(
          row['doctors'],
          (d) => DoctorModel.parse(d, clinicId),
        ),
      );
    });
  }
}
