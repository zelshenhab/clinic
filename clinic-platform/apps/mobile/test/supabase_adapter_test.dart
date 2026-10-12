import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/authentication/data/repositories/supabase_auth_repository.dart';
import 'package:clinic_mobile/features/authentication/data/repositories/auth_error_mapper.dart';

void main() {
  test(
    'real SDK sends phone OTP request and maps provider expiry; no session is invented',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://supabase.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return request.url.path.endsWith('/otp')
              ? http.Response(
                  '{}',
                  200,
                  headers: {'content-type': 'application/json'},
                )
              : http.Response(
                  jsonEncode({
                    'error_code': 'otp_expired',
                    'msg': 'Provider details must not reach UI',
                  }),
                  403,
                  headers: {'content-type': 'application/json'},
                );
        }),
      );
      final repo = SupabaseAuthRepository(client, smsEnabled: true);
      await repo.sendOtp('+79991234567');
      expect(jsonDecode(requests.first.body)['phone'], '+79991234567');
      await expectLater(
        repo.verifyOtp('+79991234567', '111111'),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.otpExpired,
          ),
        ),
      );
      expect(repo.current, isNull);
      expect(repo.accessToken, isNull);
      client.dispose();
    },
  );
  test('concurrent refresh callers share one SDK refresh operation', () async {
    final response = Completer<http.Response>();
    int calls = 0;
    final client = SupabaseClient(
      'https://supabase.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) {
        calls++;
        return response.future;
      }),
    );
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.${base64Url.encode(utf8.encode('{"exp":2000000000,"sub":"test-user"}')).replaceAll('=', '')}.signature';
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'test-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {
          'id': 'test-user',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
          'phone': '+79991234567',
        },
      }),
    );
    final repo = SupabaseAuthRepository(client, smsEnabled: true);
    final a = repo.refresh(), b = repo.refresh();
    response.complete(
      http.Response(
        jsonEncode({
          'access_token': token,
          'refresh_token': 'next-refresh',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': {
            'id': 'test-user',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
            'phone': '+79991234567',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(await a, token);
    expect(await b, token);
    expect(calls, 1);
    client.dispose();
  });
  test(
    'distinguishes retryable network, expired session, and OTP failures',
    () {
      expect(authErrorKind(AuthRetryableFetchException()), FailureKind.network);
      expect(
        authErrorKind(const AuthException('hidden', code: 'invalid_jwt')),
        FailureKind.unauthorized,
      );
      expect(
        authErrorKind(
          const AuthException('hidden', code: 'invalid_credentials'),
          otp: true,
        ),
        FailureKind.otpInvalid,
      );
    },
  );
}
