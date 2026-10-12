class Clinic {
  const Clinic({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.timezone,
    this.imageUrl,
    this.logoUrl,
    this.phone,
    this.workingHours = const {},
  });
  final String id, timezone;
  final Map<String, String> name, address, description;
  final String? imageUrl, logoUrl, phone;
  final Map<String, dynamic> workingHours;
  String text(Map<String, String> value, String locale) =>
      value[locale] ?? value['ru'] ?? '';
}
