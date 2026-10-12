import 'dart:async';
import 'dart:io';
import 'auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/auth_identity.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, {required this.smsEnabled});
  final SupabaseClient? client;
  final bool smsEnabled;
  Future<String?>? _refreshing;
  AuthIdentity? identity(User? user) =>
      user == null ? null : AuthIdentity(user.id, user.phone ?? '');
  @override
  bool get configured => client != null && smsEnabled;
  @override
  AuthIdentity? get current => identity(client?.auth.currentUser);
  @override
  String? get accessToken => client?.auth.currentSession?.accessToken;
  @override
  Stream<AuthIdentity?> get changes =>
      client?.auth.onAuthStateChange
          .map((event) => identity(event.session?.user))
          .handleError((Object error) {
            throw AppException(
              error is AuthException
                  ? authErrorKind(error)
                  : FailureKind.unknown,
            );
          }) ??
      const Stream.empty();
  Future<T> safe<T>(Future<T> Function() work, {bool otp = false}) async {
    try {
      return await work().timeout(const Duration(seconds: 15));
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(authErrorKind(e, otp: otp));
    } on SocketException {
      throw const AppException(FailureKind.network);
    } on TimeoutException {
      throw const AppException(FailureKind.timeout);
    } catch (_) {
      throw const AppException(FailureKind.unknown);
    }
  }

  @override
  Future<AuthIdentity?> restore() async {
    if (client?.auth.currentSession == null) return null;
    if (client!.auth.currentSession!.isExpired) {
      final token = await refresh();
      if (token == null) return null;
    }
    return safe(() async {
      final result = await client!.auth.getUser();
      return identity(result.user);
    });
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (!configured) throw const AppException(FailureKind.configuration);
    await safe(() => client!.auth.signInWithOtp(phone: phone), otp: true);
  }

  @override
  Future<AuthIdentity> verifyOtp(String phone, String code) async {
    if (!configured) throw const AppException(FailureKind.configuration);
    return safe(() async {
      final result = await client!.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );
      if (result.user == null || result.session == null) {
        throw const AppException(FailureKind.unauthorized);
      }
      return identity(result.user)!;
    }, otp: true);
  }

  @override
  Future<String?> refresh() {
    if (_refreshing != null) return _refreshing!;
    return _refreshing = _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    if (client?.auth.currentSession == null) return null;
    try {
      return await safe(
        () async => (await client!.auth.refreshSession()).session?.accessToken,
      );
    } on AppException catch (e) {
      if (e.kind == FailureKind.unauthorized) {
        await expire();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    if (client != null) await safe(() => client!.auth.signOut());
  }

  @override
  Future<void> expire() async {
    if (client != null) {
      await safe(() => client!.auth.signOut(scope: SignOutScope.local));
    }
  }
}
