import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/clinic_selection/domain/usecases/load_clinics.dart';
import 'package:clinic_mobile/features/clinic_selection/presentation/bloc/clinic_cubit.dart';
import 'support/fakes.dart';

void main() {
  test(
    'restores only a real active clinic UUID and persists a switch',
    () async {
      final preferences = MemoryPreferences();
      await preferences.write('selected_clinic_id', clinicA.id);
      final scope = ClinicScope();
      final cubit = ClinicCubit(LoadClinics(FakeClinics()), preferences, scope);
      await cubit.load();
      expect(cubit.state.selected!.id, clinicA.id);
      final old = scope.token;
      await cubit.select(clinicB);
      expect(old.isCancelled, true);
      expect(cubit.state.selected!.id, clinicB.id);
      expect(preferences.read('selected_clinic_id'), clinicB.id);
      await cubit.close();
    },
  );
  test('does not restore a removed clinic or human-readable slug', () async {
    final preferences = MemoryPreferences();
    await preferences.write('selected_clinic_id', 'clinic_001');
    final cubit = ClinicCubit(
      LoadClinics(FakeClinics()),
      preferences,
      ClinicScope(),
    );
    await cubit.load();
    expect(cubit.state.selected, isNull);
    expect(cubit.state.restored, true);
    await cubit.close();
  });
  test('rapid switching leaves latest clinic selected and persisted', () async {
    final preferences = MemoryPreferences();
    final cubit = ClinicCubit(
      LoadClinics(FakeClinics()),
      preferences,
      ClinicScope(),
    );
    await cubit.load();
    await Future.wait([cubit.select(clinicA), cubit.select(clinicB)]);
    expect(cubit.state.selected!.id, clinicB.id);
    expect(preferences.read('selected_clinic_id'), clinicB.id);
    await cubit.close();
  });
  test('supports retry after a typed repository failure', () async {
    final repository = FakeClinics()
      ..failure = const AppException(FailureKind.network);
    final cubit = ClinicCubit(
      LoadClinics(repository),
      MemoryPreferences(),
      ClinicScope(),
    );
    await cubit.load();
    expect(cubit.state.failure, FailureKind.network);
    repository.failure = null;
    await cubit.load();
    expect(cubit.state.status, ClinicStatus.success);
    await cubit.close();
  });
}
