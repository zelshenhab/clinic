class Specialty {
  const Specialty({
    required this.id,
    required this.clinicId,
    required this.name,
    required this.description,
    required this.icon,
    required this.doctorCount,
  });
  final String id, clinicId, icon;
  final Map<String, String> name, description;
  final int doctorCount;
}
