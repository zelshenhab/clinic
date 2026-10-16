class ClinicNotification {
  const ClinicNotification(
    this.id,
    this.title,
    this.body, {
    this.readAt,
    this.kind = "general",
    this.context = const {},
  });
  final DateTime? readAt;
  final String kind;
  final Map<String, dynamic> context;
  final String id;
  final Map<String, String> title, body;
}
