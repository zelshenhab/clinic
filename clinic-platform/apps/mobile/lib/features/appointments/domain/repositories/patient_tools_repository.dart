import '../../../../core/cancellation/request_cancellation.dart';

class BookingPolicy {
  const BookingPolicy(this.cancelMinutes, this.moveMinutes);
  final int cancelMinutes, moveMinutes;
}

class WaitlistEntry {
  const WaitlistEntry({
    required this.id,
    required this.doctorId,
    required this.serviceId,
    required this.day,
    required this.state,
    this.doctorName = const {},
    this.serviceName = const {},
  });
  final String id, doctorId, serviceId, day, state;
  final Map<String, String> doctorName, serviceName;
}

class NearestAppointment {
  const NearestAppointment({
    required this.doctorId,
    required this.serviceId,
    required this.doctorName,
    required this.serviceName,
    required this.startsAt,
    required this.price,
  });
  final String doctorId, serviceId;
  final Map<String, String> doctorName, serviceName;
  final DateTime startsAt;
  final double price;
}

class NearestResults {
  const NearestResults(
    this.items,
    this.specialties,
    this.searchedUntil,
    this.limited,
  );
  final List<NearestAppointment> items;
  final Map<String, Map<String, String>> specialties;
  final String searchedUntil;
  final bool limited;
}

abstract interface class PatientToolsRepository {
  Future<BookingPolicy> policy(String clinic);
  Future<void> cancel(String clinic, String id, DateTime version);
  Future<void> reschedule(
    String clinic,
    String id,
    DateTime version,
    DateTime start,
  );
  Future<List<WaitlistEntry>> waitlist(
    String clinic,
    RequestCancellation token,
  );
  Future<void> joinWaitlist(
    String clinic,
    String doctor,
    String service,
    String day,
  );
  Future<void> leaveWaitlist(String clinic, String id);
  Future<void> readNotification(String clinic, String id);
  Future<NearestResults> nearest(
    String clinic,
    String? specialty,
    RequestCancellation token,
  );
}

abstract interface class PatientUpdates {
  Stream<void> watch(String clinic);
}
