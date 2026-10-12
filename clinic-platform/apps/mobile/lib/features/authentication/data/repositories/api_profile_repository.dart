import '../../../../core/network/api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/auth_identity.dart';
import '../../domain/repositories/profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this.api);
  final ApiClient api;
  PatientProfile parse(dynamic data) {
    try {
      return PatientProfile(
        id: data['id'] as String,
        fullName: data['full_name'] as String,
        email: data['email'] as String?,
      );
    } catch (_) {
      throw const AppException(FailureKind.invalidResponse);
    }
  }

  @override
  Future<PatientProfile?> get() async {
    final data = await api.get('/me/profile', private: true);
    return data == null ? null : parse(data);
  }

  @override
  Future<PatientProfile> save(
    String name,
    String? email,
    String language,
  ) async => parse(
    await api.patch('/me/profile', {
      'full_name': name,
      'email': email,
      'language': language,
    }),
  );
}
