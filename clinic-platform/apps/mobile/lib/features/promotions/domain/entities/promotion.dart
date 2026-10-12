class Promotion {
  const Promotion({
    required this.id,
    required this.clinicId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.action,
  });
  final String id, clinicId;
  final Map<String, String> title, description;
  final String? imageUrl, action;
}
