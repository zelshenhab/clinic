import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/booking_repository.dart';

class BookingFlowState {
  const BookingFlowState({
    this.slots = const [],
    this.loading = false,
    this.busy = false,
    this.selected,
    this.receipt,
    this.failure,
  });
  final List<AvailableSlot> slots;
  final bool loading, busy;
  final DateTime? selected;
  final BookingReceipt? receipt;
  final FailureKind? failure;
}

class BookingFlowCubit extends Cubit<BookingFlowState> {
  BookingFlowCubit(
    this.scope,
    this.repository,
    this.updates, {
    this.refreshInterval = const Duration(seconds: 15),
  }) : super(const BookingFlowState()) {
    _remove = scope.onReset(_reset);
  }
  final ClinicScope scope;
  final BookingRepository repository;
  final AvailabilityUpdates updates;
  final Duration refreshInterval;
  late final void Function() _remove;
  String? _clinic, _doctor, _service, _date;
  int _version = 0;
  RequestCancellation? _read, _write;
  StreamSubscription<void>? _subscription;
  Timer? _timer, _debounce;
  bool _reading = false, _again = false;
  void _reset() {
    _version++;
    _read?.cancel();
    _write?.cancel();
    _subscription?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    _clinic = null;
    _reading = false;
    _again = false;
    emit(const BookingFlowState());
  }

  Future<void> configure(
    String clinic,
    String doctor,
    String service,
    String date,
  ) async {
    if (_clinic == clinic &&
        _doctor == doctor &&
        _service == service &&
        _date == date) {
      return;
    }
    _reset();
    _clinic = clinic;
    _doctor = doctor;
    _service = service;
    _date = date;
    _subscription = updates.watch(clinic, doctor).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        refresh();
      });
    }, onError: (Object _) {});
    _timer = Timer.periodic(refreshInterval, (_) {
      refresh();
    });
    await refresh();
  }

  Future<void> refresh() async {
    if (isClosed || _clinic == null || state.busy) return;
    if (_reading) {
      _again = true;
      return;
    }
    _reading = true;
    final version = _version,
        generation = scope.generation,
        token = _read = RequestCancellation(),
        remove = scope.token.listen(token.cancel);
    emit(
      BookingFlowState(
        slots: state.slots,
        loading: true,
        selected: state.selected,
        receipt: state.receipt,
        failure: state.failure,
      ),
    );
    try {
      final slots = await repository.availability(
        _clinic!,
        _doctor!,
        _service!,
        _date!,
        token,
      );
      if (!isClosed && version == _version && scope.current(generation)) {
        emit(
          BookingFlowState(
            slots: slots,
            selected: slots.any((s) => s.startsAt == state.selected)
                ? state.selected
                : null,
            receipt: state.receipt,
            failure: state.failure,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && version == _version && scope.current(generation)) {
        emit(
          BookingFlowState(
            slots: state.slots,
            receipt: state.receipt,
            failure: error is AppException ? error.kind : FailureKind.unknown,
          ),
        );
      }
    } finally {
      remove();
      if (version == _version) {
        _reading = false;
        if (_again) {
          _again = false;
          refresh();
        }
      }
    }
  }

  void select(DateTime value) {
    if (!state.busy &&
        !state.loading &&
        state.slots.any((s) => s.startsAt == value)) {
      emit(BookingFlowState(slots: state.slots, selected: value));
    }
  }

  Future<void> book() async {
    if (state.busy ||
        state.loading ||
        state.selected == null ||
        _clinic == null) {
      return;
    }
    final chosen = state.selected!,
        version = _version,
        generation = scope.generation,
        token = _write = RequestCancellation(),
        remove = scope.token.listen(token.cancel);
    _read?.cancel();
    emit(BookingFlowState(slots: state.slots, selected: chosen, busy: true));
    try {
      final receipt = await repository.book(
        _clinic!,
        _doctor!,
        _service!,
        chosen,
        token,
      );
      if (!isClosed && version == _version && scope.current(generation)) {
        emit(
          BookingFlowState(
            slots: state.slots.where((s) => s.startsAt != chosen).toList(),
            receipt: receipt,
          ),
        );
        await refresh();
      }
    } catch (error) {
      if (!isClosed && version == _version && scope.current(generation)) {
        emit(
          BookingFlowState(
            slots: state.slots,
            failure: error is AppException ? error.kind : FailureKind.unknown,
          ),
        );
        await refresh();
      }
    } finally {
      remove();
    }
  }

  @override
  Future<void> close() {
    _remove();
    _read?.cancel();
    _write?.cancel();
    _subscription?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    return super.close();
  }
}
