import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/home_catalog.dart';
import '../../domain/repositories/home_repository.dart';
import '../../../clinic_selection/data/models/clinic_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../services/data/models/service_model.dart';
import '../../../specialties/data/models/specialty_model.dart';
import '../../../promotions/data/models/promotion_model.dart';

class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this.api);
  final ApiClient api;
  @override
  Future<HomeCatalog> get(
    String clinicId,
    RequestCancellation token,
    String locale,
  ) async {
    final data = await api.get(
      '/clinics/$clinicId/home?locale=$locale',
      cancelToken: token,
    );
    return CatalogParser.safe(() {
      final row = CatalogParser.object(data),
          clinic = ClinicModel.parse(row['clinic']);
      if (clinic.id != clinicId) throw const FormatException();
      return HomeCatalog(
        clinic: clinic,
        promotions: (row['promotions'] as List)
            .map((p) => PromotionModel.parse(p, clinicId))
            .toList(),
        specialties: (row['specialties'] as List)
            .map((s) => SpecialtyModel.parse(s, clinicId))
            .toList(),
        doctors: (row['doctors'] as List)
            .map((d) => DoctorModel.parse(d, clinicId))
            .toList(),
        services: (row['services'] as List)
            .map((s) => ServiceModel.parse(s, clinicId))
            .toList(),
      );
    });
  }
}
