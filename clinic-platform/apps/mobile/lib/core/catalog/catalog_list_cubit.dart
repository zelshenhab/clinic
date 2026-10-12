import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cancellation/request_cancellation.dart';
import '../errors/app_exception.dart';
import '../network/clinic_scope.dart';
import 'catalog_query.dart';
import 'catalog_page.dart';

enum CatalogStatus { initial, loading, loaded, empty, error }

class CatalogListState<T> {
  const CatalogListState({
    this.status = CatalogStatus.initial,
    this.items = const [],
    this.query = const CatalogQuery(),
    this.clinicId,
    this.total = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
    this.categories = const {},
  });
  final CatalogStatus status;
  final List<T> items;
  final CatalogQuery query;
  final String? clinicId;
  final int total;
  final bool hasMore, loadingMore;
  final FailureKind? failure;
  final Map<String, Map<String, String>> categories;
}

typedef PageLoader<T> =
    Future<CatalogPage<T>> Function(
      String clinicId,
      RequestCancellation token, {
      CatalogQuery query,
    });

class CatalogListCubit<T> extends Cubit<CatalogListState<T>> {
  CatalogListCubit(this.scope, this.loader) : super(CatalogListState<T>()) {
    _remove = scope.onReset(reset);
  }
  final ClinicScope scope;
  final PageLoader<T> loader;
  late final void Function() _remove;
  RequestCancellation? _token;
  Timer? _debounce;
  int _version = 0;
  String? _key;
  Future<void>? _active;
  void reset() {
    _version++;
    _token?.cancel();
    _debounce?.cancel();
    _key = null;
    emit(CatalogListState<T>());
  }

  Future<void> load(
    String clinic, {
    CatalogQuery query = const CatalogQuery(),
    bool force = false,
  }) {
    final key = '$clinic:${query.path('')}';
    if (!force && key == _key && _active != null) return _active!;
    _key = key;
    _debounce?.cancel();
    return _active = _fetch(clinic, query, false);
  }

  Future<void> _fetch(String clinic, CatalogQuery query, bool append) async {
    _token?.cancel();
    final token = _token = RequestCancellation();
    final remove = scope.token.listen(token.cancel);
    final version = ++_version, generation = scope.generation;
    final previous = state;
    emit(
      CatalogListState<T>(
        status: append ? previous.status : CatalogStatus.loading,
        items: append ? previous.items : [],
        query: query,
        clinicId: clinic,
        total: append ? previous.total : 0,
        hasMore: append && previous.hasMore,
        loadingMore: append,
        categories: previous.categories,
      ),
    );
    try {
      final page = await loader(clinic, token, query: query);
      if (isClosed || version != _version || !scope.current(generation)) return;
      final items = append ? [...previous.items, ...page.items] : page.items;
      emit(
        CatalogListState<T>(
          status: items.isEmpty ? CatalogStatus.empty : CatalogStatus.loaded,
          items: items,
          query: query,
          clinicId: clinic,
          total: page.total,
          hasMore: page.hasMore,
          categories: page.categories,
        ),
      );
    } catch (error) {
      final kind = error is AppException ? error.kind : FailureKind.unknown;
      if (!isClosed &&
          version == _version &&
          scope.current(generation) &&
          kind != FailureKind.cancelled) {
        emit(
          CatalogListState<T>(
            status: CatalogStatus.error,
            items: append ? previous.items : [],
            query: append ? previous.query : query,
            clinicId: clinic,
            total: previous.total,
            hasMore: previous.hasMore,
            failure: kind,
            categories: previous.categories,
          ),
        );
      }
    } finally {
      remove();
      if (version == _version) {
        _active = null;
        _key = null;
      }
    }
  }

  void search(String value) {
    final clinic = state.clinicId;
    if (clinic == null) return;
    final query = state.query.copy(search: value, page: 1);
    _version++;
    _token?.cancel();
    _debounce?.cancel();
    emit(
      CatalogListState<T>(
        status: CatalogStatus.loading,
        query: query,
        clinicId: clinic,
        categories: state.categories,
      ),
    );
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => load(clinic, query: query, force: true),
    );
  }

  Future<void> filter(CatalogQuery query) => state.clinicId == null
      ? Future.value()
      : load(state.clinicId!, query: query.copy(page: 1), force: true);
  Future<void> refresh() => state.clinicId == null
      ? Future.value()
      : load(state.clinicId!, query: state.query.copy(page: 1), force: true);
  Future<void> next() async {
    if (!state.hasMore || state.loadingMore || state.clinicId == null) return;
    await _fetch(
      state.clinicId!,
      state.query.copy(page: state.query.page + 1),
      true,
    );
  }

  @override
  Future<void> close() {
    _token?.cancel();
    _debounce?.cancel();
    _remove();
    return super.close();
  }
}
