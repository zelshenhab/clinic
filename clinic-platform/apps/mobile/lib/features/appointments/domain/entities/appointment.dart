class Appointment {
  const Appointment({
    required this.id,
    required this.clinicId,
    required this.startsAt,
    required this.status,
    this.doctorId,
    this.serviceId,
    this.updatedAt,
    this.doctorName = const {},
    this.serviceName = const {},
    this.attendanceStatus = "scheduled",
  });
  final String id, clinicId, status;
  final DateTime startsAt;
  final String? doctorId, serviceId;
  final DateTime? updatedAt;
  final Map<String, String> doctorName, serviceName;
  final String attendanceStatus;
}
