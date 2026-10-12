import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/preferences.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/clinic.dart';
import '../../domain/usecases/load_clinics.dart';

enum ClinicStatus { initial, loading, success, empty, error }

class ClinicState {
  const ClinicState({
    this.status = ClinicStatus.initial,
    this.clinics = const [],
    this.selected,
    this.failure,
    this.restored = false,
  });
  final ClinicStatus status;
  final List<Clinic> clinics;
  final Clinic? selected;
  final FailureKind? failure;
  final bool restored;
}

class ClinicCubit extends Cubit<ClinicState> {
  ClinicCubit(this.loadClinics, this.preferences, this.scope)
    : super(const ClinicState());
  final LoadClinics loadClinics;
  final Preferences preferences;
  final ClinicScope scope;
  int _loadVersion = 0;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    final version = ++_loadVersion;
    emit(
      ClinicState(
        status: ClinicStatus.loading,
        selected: state.selected,
        restored: state.restored,
      ),
    );
    try {
      final clinics = await loadClinics();
      if (isClosed || version != _loadVersion) return;
      final saved = preferences.read('selected_clinic_id');
      final matches = clinics.where((c) => c.id == saved);
      final selected = matches.isEmpty ? null : matches.first;
      if (state.selected?.id != selected?.id) scope.invalidate();
      emit(
        ClinicState(
          status: clinics.isEmpty ? ClinicStatus.empty : ClinicStatus.success,
          clinics: clinics,
          selected: selected,
          restored: true,
        ),
      );
    } on AppException catch (e) {
      if (!isClosed && version == _loadVersion) {
        emit(
          ClinicState(
            status: ClinicStatus.error,
            selected: state.selected,
            failure: e.kind,
            restored: true,
          ),
        );
      }
    }
  }

  Future<void> select(Clinic clinic) {
    if (!state.clinics.any((c) => c.id == clinic.id)) {
      throw const AppException(FailureKind.validation);
    }
    _loadVersion++;
    scope.invalidate();
    final version = scope.generation;
    final clinics = state.clinics;
    emit(
      ClinicState(
        status: ClinicStatus.loading,
        clinics: clinics,
        restored: true,
      ),
    );
    return _writes = _writes.then((_) async {
      try {
        await preferences.write('selected_clinic_id', clinic.id);
        if (!isClosed && scope.current(version)) {
          emit(
            ClinicState(
              status: ClinicStatus.success,
              clinics: clinics,
              selected: clinic,
              restored: true,
            ),
          );
        }
      } on AppException catch (e) {
        if (!isClosed && scope.current(version)) {
          emit(
            ClinicState(
              status: ClinicStatus.error,
              clinics: clinics,
              failure: e.kind,
              restored: true,
            ),
          );
        }
      }
    });
  }
}
