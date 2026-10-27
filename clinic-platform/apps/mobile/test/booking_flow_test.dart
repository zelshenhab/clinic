import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/appointments/domain/repositories/booking_repository.dart';
import 'package:clinic_mobile/features/appointments/presentation/bloc/booking_flow_cubit.dart';

class BookingFake implements BookingRepository {
  List<AvailableSlot> slots = [
    AvailableSlot(
      DateTime.utc(2026, 12, 1, 6),
      DateTime.utc(2026, 12, 1, 6, 30),
    ),
  ];
  int bookings = 0, reads = 0;
  String? bookedFor;
  Completer<BookingReceipt>? pending;
  FailureKind? failure;
  @override
  Future<List<AvailableSlot>> availability(
    String c,
    String d,
    String s,
    String date,
    RequestCancellation t,
  ) async {
    reads++;
    return slots;
  }

  @override
  Future<BookingReceipt> book(
    String c,
    String d,
    String s,
    DateTime starts,
    RequestCancellation t, {
    String? familyMemberId,
  }) async {
    bookings++;
    bookedFor = familyMemberId;
    if (failure != null) {
      slots = [];
      throw AppException(failure!);
    }
    if (pending != null) return pending!.future;
    slots = [];
    return BookingReceipt(
      id: 'saved-appointment',
      startsAt: starts,
      status: 'pending',
      price: 1000,
    );
  }
}

class UpdatesFake implements AvailabilityUpdates {
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> watch(String c, String d) => controller.stream;
}

void main() {
  test(
    'booking is shown only after commit, removes the slot and prevents duplicate submits',
    () async {
      final repo = BookingFake(),
          updates = UpdatesFake(),
          cubit = BookingFlowCubit(ClinicScope(), repo, updates);
      await cubit.configure('c', 'd', 's', '2026-12-01');
      final slot = repo.slots.first.startsAt;
      cubit.select(slot);
      repo.pending = Completer();
      final booking = cubit.book();
      await cubit.book();
      expect(repo.bookings, 1);
      expect(cubit.state.busy, true);
      expect(cubit.state.receipt, isNull);
      repo.slots = [];
      repo.pending!.complete(
        BookingReceipt(
          id: 'committed',
          startsAt: slot,
          status: 'pending',
          price: 1000,
        ),
      );
      await booking;
      expect(cubit.state.receipt!.id, 'committed');
      expect(cubit.state.slots, isEmpty);
      expect(cubit.state.selected, isNull);
      await cubit.close();
      await updates.controller.close();
    },
  );
  test('conflict refreshes available slots without a fake receipt', () async {
    final repo = BookingFake(),
        updates = UpdatesFake(),
        cubit = BookingFlowCubit(ClinicScope(), repo, updates);
    await cubit.configure('c', 'd', 's', '2026-12-01');
    cubit.select(repo.slots.first.startsAt);
    repo.failure = FailureKind.bookingConflict;
    await cubit.book();
    expect(cubit.state.failure, FailureKind.bookingConflict);
    expect(cubit.state.receipt, isNull);
    expect(cubit.state.slots, isEmpty);
    await cubit.close();
    await updates.controller.close();
  });
  test(
    'availability events invalidate a selected slot and stop after scope reset',
    () async {
      final repo = BookingFake(),
          updates = UpdatesFake(),
          scope = ClinicScope(),
          cubit = BookingFlowCubit(scope, repo, updates);
      await cubit.configure('c', 'd', 's', '2026-12-01');
      cubit.select(repo.slots.first.startsAt);
      repo.slots = [];
      updates.controller.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(cubit.state.selected, isNull);
      expect(cubit.state.slots, isEmpty);
      final reads = repo.reads;
      scope.invalidate();
      updates.controller.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(repo.reads, reads);
      expect(cubit.state.receipt, isNull);
      await cubit.close();
      await updates.controller.close();
    },
  );
}
