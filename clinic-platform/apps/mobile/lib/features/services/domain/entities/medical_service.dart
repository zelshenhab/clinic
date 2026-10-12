class MedicalService {
  const MedicalService({
    required this.id,
    required this.clinicId,
    required this.specialtyId,
    required this.name,
    required this.description,
    required this.specialtyName,
    required this.category,
    required this.categoryKey,
    required this.price,
    required this.duration,
  });
  final String id, clinicId, specialtyId, categoryKey;
  final Map<String, String> name, description, specialtyName, category;
  final double price;
  final int duration;
}
