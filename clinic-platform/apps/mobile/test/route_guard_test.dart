import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/app/router/route_guard.dart';
import 'package:clinic_mobile/features/authentication/presentation/bloc/auth_cubit.dart';
import 'package:clinic_mobile/features/authentication/domain/entities/auth_identity.dart';

void main() {
  String? guard(
    String path, {
    bool selected = true,
    bool ready = true,
    AuthState auth = const AuthState(status: AuthStatus.guest),
  }) => guardRoute(
    path: path,
    ready: ready,
    clinicSelected: selected,
    auth: auth,
  );
  test(
    'restoration precedes clinic selection and personal routes require login',
    () {
      expect(guard('/home', ready: false), '/splash');
      expect(guard('/home', selected: false), '/clinics');
      expect(guard('/doctors'), isNull);
      expect(guard('/profile'), isNull);
      expect(guard('/appointments'), '/login?from=appointments');
      expect(guard('/settings', selected: false), isNull);
    },
  );
  test('returning users can enter home and appointments immediately', () {
    const auth = AuthState(
      status: AuthStatus.authenticated,
      identity: AuthIdentity('u', '+7'),
      profile: PatientProfile(id: 'u', fullName: 'Demo'),
    );
    expect(guard('/home', auth: auth), isNull);
    expect(guard('/appointments', auth: auth), isNull);
    expect(guard('/login', auth: auth), '/home');
  });
  test('missing profiles cannot bypass completion', () {
    const auth = AuthState(
      status: AuthStatus.profileRequired,
      identity: AuthIdentity('u', '+7'),
    );
    expect(guard('/appointments', auth: auth), '/profile-completion');
  });
}
