import 'specialty.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../services/domain/entities/medical_service.dart';
import '../../../../core/catalog/catalog_page.dart';

class SpecialtyDetail {
  const SpecialtyDetail(this.specialty, this.doctors, this.services);
  final Specialty specialty;
  final CatalogPage<Doctor> doctors;
  final CatalogPage<MedicalService> services;
}
