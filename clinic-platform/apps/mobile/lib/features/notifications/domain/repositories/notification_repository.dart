import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/clinic_notification.dart';

abstract interface class NotificationRepository {
  Future<List<ClinicNotification>> list(
    String clinic,
    RequestCancellation token,
  );
}
