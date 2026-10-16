import 'dart:async';
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
  ScopedListCubit(this.scope, this.loader, {this.updates})
    : super(ListState<T>()) {
    _remove = scope.onReset(() {
      _stopUpdates();
      ++_request;
      emit(ListState<T>());
    });
  }
  final ClinicScope scope;
  final Future<List<T>> Function(String clinicId, RequestCancellation token)
  loader;
  late final void Function() _remove;
  int _request = 0;
  final Stream<void> Function(String clinic)? updates;
  StreamSubscription<void>? _subscription;
  Timer? _poll, _debounce;
  String? _watching;
  void _stopUpdates() {
    _subscription?.cancel();
    _subscription = null;
    _poll?.cancel();
    _debounce?.cancel();
    _watching = null;
  }

  void _watch(String clinic) {
    if (updates == null || _watching == clinic) return;
    _stopUpdates();
    _watching = clinic;
    _subscription = updates!(clinic).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () => load(clinic));
    }, onError: (Object _) {});
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => load(clinic));
  }

  Future<void> load(String clinicId) async {
    if (isClosed) return;
    _watch(clinicId);
    final generation = scope.generation, request = ++_request;
    if (state.clinicId != clinicId || state.items.isEmpty) {
      emit(ListState<T>(status: ListStatus.loading, clinicId: clinicId));
    }
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
    _stopUpdates();
    _remove();
    return super.close();
  }
}
