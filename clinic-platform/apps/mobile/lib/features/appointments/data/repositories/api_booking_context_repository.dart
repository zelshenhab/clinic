import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/network/api_client.dart';
import '../../../clinic_selection/data/models/clinic_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../services/data/models/service_model.dart';
import '../../../specialties/data/models/specialty_model.dart';
import '../../domain/entities/booking_context.dart';
import '../../domain/repositories/booking_context_repository.dart';

class ApiBookingContextRepository implements BookingContextRepository {
  ApiBookingContextRepository(this.api);
  final ApiClient api;
  @override
  Future<BookingContext> get(
    String clinicId,
    CatalogQuery query,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      query.path('/clinics/$clinicId/booking-context'),
      cancelToken: token,
    );
    return CatalogParser.safe(() {
      final row = CatalogParser.object(data);
      final clinic = ClinicModel.parse(row['clinic']);
      if (clinic.id != clinicId || row['online_booking_enabled'] is! bool) {
        throw const FormatException();
      }
      return BookingContext(
        clinic,
        row['doctor'] == null
            ? null
            : DoctorModel.parse(row['doctor'], clinicId),
        row['service'] == null
            ? null
            : ServiceModel.parse(row['service'], clinicId),
        row['specialty'] == null
            ? null
            : SpecialtyModel.parse(row['specialty'], clinicId),
      );
    });
  }
}
