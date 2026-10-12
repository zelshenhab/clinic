import '../entities/auth_identity.dart';

abstract interface class ProfileRepository {
  Future<PatientProfile?> get();
  Future<PatientProfile> save(String name, String? email, String language);
}
