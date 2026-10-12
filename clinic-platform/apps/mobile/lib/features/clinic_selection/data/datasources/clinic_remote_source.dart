import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../../../../core/network/api_client.dart';

class ClinicRemoteSource {
  ClinicRemoteSource(this.api);
  final ApiClient api;
  Future<dynamic> list(RequestCancellation? token) =>
      api.get('/clinics', cancelToken: token);
}
