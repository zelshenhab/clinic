import '../../features/authentication/presentation/bloc/auth_cubit.dart';

String? guardRoute({
  required String path,
  required bool ready,
  required bool clinicSelected,
  required AuthState auth,
}) {
  if (!ready) return path == '/splash' ? null : '/splash';
  if (path == '/settings') return null;
  if (!clinicSelected) return path == '/clinics' ? null : '/clinics';
  if (path == '/clinics') return null;
  if (auth.signedIn &&
      auth.status != AuthStatus.authenticated &&
      auth.profile?.complete != true) {
    return path == '/profile-completion' ? null : '/profile-completion';
  }
  if (const ['/appointments', '/notifications'].contains(path) &&
      !auth.signedIn) {
    return '/login?from=${path.substring(1)}';
  }
  if (path == '/profile-completion' && !auth.signedIn) return '/login';
  if (path == '/otp' && auth.phone.isEmpty) return '/login';
  if (auth.status == AuthStatus.authenticated &&
      (path == '/login' || path == '/otp' || path == '/profile-completion')) {
    return '/home';
  }
  if (path == '/splash') return '/home';
  return null;
}
