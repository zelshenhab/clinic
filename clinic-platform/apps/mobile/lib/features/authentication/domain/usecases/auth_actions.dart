import '../entities/auth_identity.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

class AuthActions {
  AuthActions(this.auth, this.profiles);
  final AuthRepository auth;
  final ProfileRepository profiles;
  Future<AuthIdentity?> restore() => auth.restore();
  Future<void> send(String phone) => auth.sendOtp(phone);
  Future<AuthIdentity> verify(String phone, String code) =>
      auth.verifyOtp(phone, code);
  Future<PatientProfile?> profile() => profiles.get();
  Future<PatientProfile> complete(
    String name,
    String? email,
    String language,
  ) => profiles.save(name, email, language);
  Future<void> logout() => auth.logout();
}
