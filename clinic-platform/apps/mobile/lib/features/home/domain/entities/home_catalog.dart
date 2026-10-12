import '../../../clinic_selection/domain/entities/clinic.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../../services/domain/entities/medical_service.dart';
import '../../../promotions/domain/entities/promotion.dart';

class HomeCatalog {
  const HomeCatalog({
    required this.clinic,
    required this.promotions,
    required this.specialties,
    required this.doctors,
    required this.services,
  });
  final Clinic clinic;
  final List<Promotion> promotions;
  final List<Specialty> specialties;
  final List<Doctor> doctors;
  final List<MedicalService> services;
}
