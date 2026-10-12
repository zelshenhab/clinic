import '../../../clinic_selection/domain/entities/clinic.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../services/domain/entities/medical_service.dart';
import '../../../specialties/domain/entities/specialty.dart';

class BookingContext {
  const BookingContext(this.clinic, this.doctor, this.service, this.specialty);
  final Clinic clinic;
  final Doctor? doctor;
  final MedicalService? service;
  final Specialty? specialty;
}
