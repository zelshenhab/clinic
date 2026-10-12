import '../entities/auth_identity.dart';

abstract interface class AuthRepository {
  bool get configured;
  AuthIdentity? get current;
  String? get accessToken;
  Stream<AuthIdentity?> get changes;
  Future<AuthIdentity?> restore();
  Future<void> sendOtp(String phone);
  Future<AuthIdentity> verifyOtp(String phone, String code);
  Future<String?> refresh();
  Future<void> logout();
  Future<void> expire();
}
