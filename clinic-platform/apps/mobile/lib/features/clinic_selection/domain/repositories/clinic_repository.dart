import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../entities/clinic.dart';

abstract interface class ClinicRepository {
  Future<List<Clinic>> list({RequestCancellation? cancelToken});
}
