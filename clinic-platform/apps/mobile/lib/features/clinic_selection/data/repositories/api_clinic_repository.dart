import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/clinic.dart';
import '../../domain/repositories/clinic_repository.dart';
import '../datasources/clinic_remote_source.dart';
import '../models/clinic_model.dart';

class ApiClinicRepository implements ClinicRepository {
  ApiClinicRepository(this.source);
  final ClinicRemoteSource source;
  @override
  Future<List<Clinic>> list({RequestCancellation? cancelToken}) async {
    final data = await source.list(cancelToken);
    if (data is! List) throw const AppException(FailureKind.invalidResponse);
    return data.map(ClinicModel.parse).toList();
  }
}
