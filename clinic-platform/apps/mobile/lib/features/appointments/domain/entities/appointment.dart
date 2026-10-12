class Appointment {
  const Appointment({
    required this.id,
    required this.clinicId,
    required this.startsAt,
    required this.status,
  });
  final String id, clinicId, status;
  final DateTime startsAt;
}
