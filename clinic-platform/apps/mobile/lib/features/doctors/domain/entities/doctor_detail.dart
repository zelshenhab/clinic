import 'doctor.dart';
import '../../../services/domain/entities/medical_service.dart';
import '../../../clinic_selection/domain/entities/clinic.dart';
import '../../../../core/catalog/catalog_page.dart';

class DoctorSchedule {
  const DoctorSchedule(this.weekday, this.start, this.end);
  final int weekday;
  final String start, end;
}

class DoctorDetail {
  const DoctorDetail({
    required this.doctor,
    required this.clinic,
    required this.education,
    required this.biography,
    required this.qualifications,
    required this.languages,
    required this.services,
    required this.schedules,
  });
  final Doctor doctor;
  final Clinic clinic;
  final Map<String, String> education, biography, qualifications;
  final List<String> languages;
  final CatalogPage<MedicalService> services;
  final List<DoctorSchedule> schedules;
}
