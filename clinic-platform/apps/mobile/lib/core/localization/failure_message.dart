import '../errors/app_exception.dart';
import 'app_localizations.dart';

String failureMessage(AppLocalizations t, FailureKind? kind) => switch (kind) {
  FailureKind.network => t.networkError,
  FailureKind.timeout => t.timeoutError,
  FailureKind.unauthorized => t.sessionError,
  FailureKind.forbidden => t.forbiddenError,
  FailureKind.validation => t.validationError,
  FailureKind.server => t.serverError,
  FailureKind.notFound => t.notFoundError,
  FailureKind.bookingConflict => t.conflictError,
  FailureKind.invalidResponse => t.responseError,
  FailureKind.otpExpired => t.otpExpiredError,
  FailureKind.otpInvalid => t.otpInvalidError,
  FailureKind.rateLimited => t.rateLimitError,
  FailureKind.configuration => t.authUnavailable,
  FailureKind.storage => t.storageError,
  _ => t.unknownError,
};
