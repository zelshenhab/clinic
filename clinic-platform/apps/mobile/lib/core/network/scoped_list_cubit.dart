import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import '../errors/app_exception.dart';
import 'clinic_scope.dart';

enum ListStatus { initial, loading, success, empty, error }

class ListState<T> {
  const ListState({
    this.status = ListStatus.initial,
    this.items = const [],
    this.failure,
    this.clinicId,
  });
  final ListStatus status;
  final List<T> items;
  final FailureKind? failure;
  final String? clinicId;
}

class ScopedListCubit<T> extends Cubit<ListState<T>> {
  ScopedListCubit(this.scope, this.loader) : super(ListState<T>()) {
    _remove = scope.onReset(() => emit(ListState<T>()));
  }
  final ClinicScope scope;
  final Future<List<T>> Function(String clinicId, RequestCancellation token)
  loader;
  late final void Function() _remove;
  int _request = 0;
  Future<void> load(String clinicId) async {
    final generation = scope.generation, request = ++_request;
    emit(ListState<T>(status: ListStatus.loading, clinicId: clinicId));
    try {
      final items = await loader(clinicId, scope.token);
      if (isClosed || !scope.current(generation) || request != _request) return;
      emit(
        ListState<T>(
          status: items.isEmpty ? ListStatus.empty : ListStatus.success,
          items: items,
          clinicId: clinicId,
        ),
      );
    } on AppException catch (e) {
      if (isClosed ||
          !scope.current(generation) ||
          request != _request ||
          e.kind == FailureKind.cancelled) {
        return;
      }
      emit(
        ListState<T>(
          status: ListStatus.error,
          failure: e.kind,
          clinicId: clinicId,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _remove();
    return super.close();
  }
}
