import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/clinic_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this.api);
  final ApiClient api;
  @override
  Future<List<ClinicNotification>> list(
    String clinic,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      '/me/notifications?clinic_id=$clinic',
      cancelToken: token,
      private: true,
    );
    return CatalogParser.safe(
      () => (data as List).map((row) {
        CatalogParser.clinic(CatalogParser.object(row), clinic);
        return ClinicNotification(
          CatalogParser.id(row['id']),
          CatalogParser.text(row['title']),
          CatalogParser.text(row['body']),
        );
      }).toList(),
    );
  }
}
