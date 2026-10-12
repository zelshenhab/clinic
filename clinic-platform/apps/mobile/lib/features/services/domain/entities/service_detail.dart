import 'medical_service.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../clinic_selection/domain/entities/clinic.dart';
import '../../../../core/catalog/catalog_page.dart';

class ServiceDetail {
  const ServiceDetail(this.service, this.clinic, this.doctors);
  final MedicalService service;
  final Clinic clinic;
  final CatalogPage<Doctor> doctors;
}
