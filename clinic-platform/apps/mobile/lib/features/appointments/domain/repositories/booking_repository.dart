import '../../../../core/cancellation/request_cancellation.dart';

class AvailableSlot {
  const AvailableSlot(this.startsAt, this.endsAt);
  final DateTime startsAt, endsAt;
}

class BookingReceipt {
  const BookingReceipt({
    required this.id,
    required this.startsAt,
    required this.status,
    required this.price,
  });
  final String id, status;
  final DateTime startsAt;
  final double price;
}

abstract interface class BookingRepository {
  Future<List<AvailableSlot>> availability(
    String clinic,
    String doctor,
    String service,
    String date,
    RequestCancellation token,
  );
  Future<BookingReceipt> book(
    String clinic,
    String doctor,
    String service,
    DateTime startsAt,
    RequestCancellation token,
  );
}

abstract interface class AvailabilityUpdates {
  Stream<void> watch(String clinic, String doctor);
}
