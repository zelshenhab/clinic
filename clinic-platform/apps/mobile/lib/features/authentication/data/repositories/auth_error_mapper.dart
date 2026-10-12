import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exception.dart';

FailureKind authErrorKind(AuthException error, {bool otp = false}) {
  if (error is AuthRetryableFetchException) return FailureKind.network;
  if (error.statusCode == '429') return FailureKind.rateLimited;
  if ((int.tryParse(error.statusCode ?? '') ?? 0) >= 500) {
    return FailureKind.server;
  }
  return switch (error.code) {
    'otp_expired' => FailureKind.otpExpired,
    'otp_disabled' ||
    'sms_send_failed' ||
    'phone_provider_disabled' => FailureKind.configuration,
    'over_sms_send_rate_limit' ||
    'over_request_rate_limit' => FailureKind.rateLimited,
    'validation_failed' => FailureKind.validation,
    'invalid_jwt' ||
    'session_not_found' ||
    'refresh_token_not_found' ||
    'refresh_token_already_used' => FailureKind.unauthorized,
    _ => otp ? FailureKind.otpInvalid : FailureKind.unauthorized,
  };
}
