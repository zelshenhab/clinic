import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../entities/clinic.dart';
import '../repositories/clinic_repository.dart';

class LoadClinics {
  LoadClinics(this.repository);
  final ClinicRepository repository;
  Future<List<Clinic>> call({RequestCancellation? token}) =>
      repository.list(cancelToken: token);
}
