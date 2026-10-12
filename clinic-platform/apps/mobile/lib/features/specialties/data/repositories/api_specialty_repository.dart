import '../../../../core/network/api_client.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/specialty.dart';
import '../../domain/entities/specialty_detail.dart';
import '../../domain/repositories/specialty_repository.dart';
import '../models/specialty_model.dart';
import '../../../services/data/models/service_model.dart';
import '../../../doctors/data/models/doctor_model.dart';

class ApiSpecialtyRepository implements SpecialtyRepository {
  ApiSpecialtyRepository(this.api);
  final ApiClient api;
  @override
  Future<CatalogPage<Specialty>> list(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) async => CatalogParser.page(
    await api.get(
      query.path('/clinics/$clinicId/specialties'),
      cancelToken: token,
    ),
    (row) => SpecialtyModel.parse(row, clinicId),
  );
  @override
  Future<SpecialtyDetail> detail(
    String clinicId,
    String id,
    RequestCancellation token, {
    String locale = 'ru',
  }) async {
    final data = await api.get(
      '/clinics/$clinicId/specialties/$id?locale=$locale',
      cancelToken: token,
    );
    return CatalogParser.safe(() {
      final row = CatalogParser.object(data);
      return SpecialtyDetail(
        SpecialtyModel.parse(row, clinicId),
        CatalogParser.page(
          row['doctors'],
          (d) => DoctorModel.parse(d, clinicId),
        ),
        CatalogParser.page(
          row['services'],
          (s) => ServiceModel.parse(s, clinicId),
        ),
      );
    });
  }
}
