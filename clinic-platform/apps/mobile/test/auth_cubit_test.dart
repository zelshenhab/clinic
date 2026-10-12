import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/authentication/domain/entities/auth_identity.dart';
import 'package:clinic_mobile/features/authentication/domain/usecases/auth_actions.dart';
import 'package:clinic_mobile/features/authentication/domain/usecases/phone_number.dart';
import 'package:clinic_mobile/features/authentication/presentation/bloc/auth_cubit.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late AuthCubit cubit;
  late DateTime now;
  setUp(() {
    auth = FakeAuth();
    profiles = FakeProfiles();
    now = DateTime.utc(2026, 10, 12);
    cubit = AuthCubit(
      AuthActions(auth, profiles),
      ClinicScope(),
      now: () => now,
    );
  });
  tearDown(() async {
    await cubit.close();
    await auth.events.close();
  });
  test('restores a completed profile without forcing OTP', () async {
    auth.identity = const AuthIdentity('test-user', '+79991234567');
    profiles.profile = const PatientProfile(id: 'test-user', fullName: 'Demo');
    await cubit.restore();
    expect(cubit.state.status, AuthStatus.authenticated);
    expect(auth.sends, 0);
  });
  test(
    'enforces resend cooldown and handles expired OTP without session',
    () async {
      await cubit.send('+79991234567');
      expect(cubit.resendSeconds, 60);
      await cubit.send('+79991234567');
      expect(auth.sends, 1);
      auth.failure = const AppException(FailureKind.otpExpired);
      await cubit.verify('111111');
      expect(cubit.state.failure, FailureKind.otpExpired);
      expect(cubit.state.signedIn, false);
      expect(cubit.resendSeconds, 60);
      now = now.add(const Duration(seconds: 61));
      auth.failure = null;
      await cubit.send('+79991234567');
      expect(auth.sends, 2);
    },
  );
  test(
    'requires profile completion after a real adapter verification result',
    () async {
      await cubit.send('+79991234567');
      await cubit.verify('111111');
      expect(cubit.state.status, AuthStatus.profileRequired);
      await cubit.complete('Demo', null, 'ru');
      expect(cubit.state.status, AuthStatus.authenticated);
      await cubit.logout();
      expect(cubit.state.status, AuthStatus.guest);
    },
  );
  test('development configuration cannot create a session', () async {
    auth.enabled = false;
    await cubit.send('+79991234567');
    expect(cubit.state.failure, FailureKind.configuration);
    expect(cubit.state.signedIn, false);
  });
  test('signout events clear authenticated personal state', () async {
    auth.identity = const AuthIdentity('test-user', '+79991234567');
    profiles.profile = const PatientProfile(id: 'test-user', fullName: 'Demo');
    await cubit.restore();
    auth.events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.profile, isNull);
    expect(cubit.state.signedIn, false);
  });
  test(
    'refresh stream errors clear expired identity and do not escape the cubit',
    () async {
      auth.identity = const AuthIdentity('test-user', '+79991234567');
      profiles.profile = const PatientProfile(
        id: 'test-user',
        fullName: 'Demo',
      );
      await cubit.restore();
      auth.events.addError(const AppException(FailureKind.unauthorized));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.signedIn, false);
      expect(cubit.state.failure, FailureKind.unauthorized);
    },
  );
  test(
    'normalizes Russian national numbers and validates international format',
    () {
      expect(PhoneNumber.normalize('+7', '8 (999) 123-45-67'), '+79991234567');
      expect(PhoneNumber.normalize('+44', '7700900123'), '+447700900123');
      expect(PhoneNumber.normalize('+7', '123'), isNull);
    },
  );
}
