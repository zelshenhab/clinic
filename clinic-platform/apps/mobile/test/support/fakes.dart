import 'dart:async';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/storage/preferences.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/clinic_selection/domain/entities/clinic.dart';
import 'package:clinic_mobile/features/clinic_selection/domain/repositories/clinic_repository.dart';
import 'package:clinic_mobile/features/authentication/domain/entities/auth_identity.dart';
import 'package:clinic_mobile/features/authentication/domain/repositories/auth_repository.dart';
import 'package:clinic_mobile/features/authentication/domain/repositories/profile_repository.dart';

const clinicA = Clinic(
  id: '12a30244-3000-4000-8000-000000000001',
  name: {'ru': 'Клиника А', 'en': 'Clinic A'},
  address: {'ru': 'Адрес А', 'en': 'Address A'},
  description: {'ru': 'Описание А', 'en': 'Description A'},
  timezone: 'Europe/Moscow',
);
const clinicB = Clinic(
  id: '12a30244-3000-4000-8000-000000000002',
  name: {'ru': 'Клиника Б', 'en': 'Clinic B'},
  address: {'ru': 'Адрес Б', 'en': 'Address B'},
  description: {'ru': 'Описание Б', 'en': 'Description B'},
  timezone: 'Europe/Moscow',
);

class MemoryPreferences implements Preferences {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class FakeClinics implements ClinicRepository {
  List<Clinic> clinics = [clinicA, clinicB];
  AppException? failure;
  @override
  Future<List<Clinic>> list({RequestCancellation? cancelToken}) async {
    if (failure != null) throw failure!;
    return clinics;
  }
}

class FakeAuth implements AuthRepository {
  final events = StreamController<AuthIdentity?>.broadcast();
  AuthIdentity? identity;
  AppException? failure;
  int refreshCalls = 0, sends = 0, expires = 0;
  bool enabled = true;
  String? token;
  Completer<String?>? refreshResult;
  @override
  bool get configured => enabled;
  @override
  AuthIdentity? get current => identity;
  @override
  String? get accessToken => token;
  @override
  Stream<AuthIdentity?> get changes => events.stream;
  @override
  Future<AuthIdentity?> restore() async {
    if (failure != null) throw failure!;
    return identity;
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (!enabled) throw const AppException(FailureKind.configuration);
    if (failure != null) throw failure!;
    sends++;
  }

  @override
  Future<AuthIdentity> verifyOtp(String phone, String code) async {
    if (failure != null) throw failure!;
    return identity = AuthIdentity('test-user', phone);
  }

  @override
  Future<String?> refresh() async {
    refreshCalls++;
    return refreshResult == null ? 'new-token' : await refreshResult!.future;
  }

  @override
  Future<void> logout() async {
    identity = null;
    events.add(null);
  }

  @override
  Future<void> expire() async {
    expires++;
    identity = null;
    events.add(null);
  }
}

class FakeProfiles implements ProfileRepository {
  PatientProfile? profile;
  AppException? failure;
  @override
  Future<PatientProfile?> get() async {
    if (failure != null) throw failure!;
    return profile;
  }

  @override
  Future<PatientProfile> save(
    String name,
    String? email,
    String language,
  ) async =>
      profile = PatientProfile(id: 'test-user', fullName: name, email: email);
}
