import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../entities/appointment.dart';

abstract interface class AppointmentRepository {
  Future<List<Appointment>> list(String clinicId, RequestCancellation token);
}
