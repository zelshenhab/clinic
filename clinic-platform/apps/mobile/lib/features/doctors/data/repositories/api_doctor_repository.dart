import '../../../../core/network/api_client.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/doctor_detail.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../models/doctor_model.dart';
import '../../../services/data/models/service_model.dart';
import '../../../clinic_selection/data/models/clinic_model.dart';

class ApiDoctorRepository implements DoctorRepository {
  ApiDoctorRepository(this.api);
  final ApiClient api;
  @override
  Future<CatalogPage<Doctor>> list(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) async => CatalogParser.page(
    await api.get(query.path('/clinics/$clinicId/doctors'), cancelToken: token),
    (row) => DoctorModel.parse(row, clinicId),
  );
  @override
  Future<DoctorDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  }) async {
    final data = await api.get(
      '/clinics/$clinicId/doctors/$id?locale=$locale',
      cancelToken: token,
    );
    return CatalogParser.safe(() {
      final row = CatalogParser.object(data);
      final clinic = ClinicModel.parse(row['clinic']);
      if (clinic.id != clinicId) throw const FormatException();
      return DoctorDetail(
        doctor: DoctorModel.parse(row, clinicId),
        clinic: clinic,
        education: CatalogParser.text(row['education']),
        biography: CatalogParser.text(row['biography']),
        qualifications: CatalogParser.text(row['qualifications']),
        languages: List<String>.from(row['languages'] as List),
        services: CatalogParser.page(
          row['services'],
          (s) => ServiceModel.parse(s, clinicId),
        ),
        schedules: (row['schedules'] as List)
            .map(
              (s) => DoctorSchedule(
                CatalogParser.integer(s['weekday'], max: 6),
                CatalogParser.time(s['starts_at']),
                CatalogParser.time(s['ends_at']),
              ),
            )
            .toList(),
      );
    });
  }
}
