import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';

class ApiAppointmentRepository implements AppointmentRepository {
  ApiAppointmentRepository(this.api);
  final ApiClient api;
  @override
  Future<List<Appointment>> list(
    String clinicId,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      '/me/appointments?clinic_id=$clinicId',
      cancelToken: token,
      private: true,
    );
    try {
      if (data is! List) throw const FormatException();
      return data.map((row) {
        if (row['clinic_id'] != clinicId) throw const FormatException();
        return Appointment(
          id: row['id'] as String,
          clinicId: row['clinic_id'] as String,
          startsAt: DateTime.parse(row['starts_at'] as String),
          status: row['status'] as String,
        );
      }).toList();
    } catch (_) {
      throw const AppException(FailureKind.invalidResponse);
    }
  }
}
