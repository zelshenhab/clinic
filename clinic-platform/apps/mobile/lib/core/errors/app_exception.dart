enum FailureKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  validation,
  server,
  notFound,
  bookingConflict,
  policyCutoff,
  slotsAvailable,
  familyLimit,
  invalidResponse,
  cancelled,
  otpExpired,
  otpInvalid,
  rateLimited,
  configuration,
  storage,
  unknown,
}

class AppException implements Exception {
  const AppException(this.kind);
  final FailureKind kind;
}
