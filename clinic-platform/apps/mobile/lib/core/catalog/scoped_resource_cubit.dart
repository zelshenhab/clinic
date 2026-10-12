import 'package:flutter_bloc/flutter_bloc.dart';
import '../network/clinic_scope.dart';
import '../cancellation/request_cancellation.dart';
import '../errors/app_exception.dart';
import 'catalog_list_cubit.dart';

class ResourceState<T> {
  const ResourceState({
    this.status = CatalogStatus.initial,
    this.data,
    this.failure,
    this.clinicId,
  });
  final CatalogStatus status;
  final T? data;
  final FailureKind? failure;
  final String? clinicId;
}

class ScopedResourceCubit<T> extends Cubit<ResourceState<T>> {
  ScopedResourceCubit(this.scope) : super(ResourceState<T>()) {
    _remove = scope.onReset(reset);
  }
  final ClinicScope scope;
  late final void Function() _remove;
  int _version = 0;
  RequestCancellation? _token;
  void reset() {
    _version++;
    _token?.cancel();
    emit(ResourceState<T>());
  }

  Future<void> fetch(
    String clinic,
    Future<T> Function(RequestCancellation token) loader,
  ) async {
    _token?.cancel();
    final token = _token = RequestCancellation();
    final remove = scope.token.listen(token.cancel);
    final version = ++_version, generation = scope.generation;
    emit(ResourceState<T>(status: CatalogStatus.loading, clinicId: clinic));
    try {
      final data = await loader(token);
      if (!isClosed && version == _version && scope.current(generation)) {
        emit(
          ResourceState<T>(
            status: CatalogStatus.loaded,
            data: data,
            clinicId: clinic,
          ),
        );
      }
    } catch (error) {
      final kind = error is AppException ? error.kind : FailureKind.unknown;
      if (!isClosed &&
          version == _version &&
          scope.current(generation) &&
          kind != FailureKind.cancelled) {
        emit(
          ResourceState<T>(
            status: CatalogStatus.error,
            clinicId: clinic,
            failure: kind,
          ),
        );
      }
    } finally {
      remove();
    }
  }

  @override
  Future<void> close() {
    _token?.cancel();
    _remove();
    return super.close();
  }
}
