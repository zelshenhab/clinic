class DoctorSpecialty {
  const DoctorSpecialty(this.id, this.name);
  final String id;
  final Map<String, String> name;
}

class Doctor {
  const Doctor({
    required this.id,
    required this.clinicId,
    required this.name,
    required this.description,
    required this.title,
    this.photoUrl,
    this.experienceYears,
    this.startingPrice,
    this.specialties = const [],
  });
  final String id, clinicId;
  final Map<String, String> name, description, title;
  final String? photoUrl;
  final int? experienceYears;
  final double? startingPrice;
  final List<DoctorSpecialty> specialties;
}
