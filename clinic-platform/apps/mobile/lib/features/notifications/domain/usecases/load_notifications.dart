import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/clinic_notification.dart';
import '../repositories/notification_repository.dart';

class LoadNotifications {
  LoadNotifications(this.repository);
  final NotificationRepository repository;
  Future<List<ClinicNotification>> call(
    String clinic,
    RequestCancellation token,
  ) => repository.list(clinic, token);
}
