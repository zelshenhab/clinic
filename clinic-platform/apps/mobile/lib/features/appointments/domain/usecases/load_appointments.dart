import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../repositories/appointment_repository.dart';
import '../entities/appointment.dart';

class LoadAppointments {
  LoadAppointments(this.repository);
  final AppointmentRepository repository;
  Future<List<Appointment>> call(String clinicId, RequestCancellation token) =>
      repository.list(clinicId, token);
}
