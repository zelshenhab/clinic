enum DocumentKind { report, labResult, imaging, prescription, other }

class MedicalDocument {
  const MedicalDocument({
    required this.id,
    required this.kind,
    required this.title,
    required this.fileName,
    required this.mimeType,
    required this.createdAt,
    this.doctorName = const {},
    this.familyMemberId,
    this.familyMemberName,
  });
  final String id, title, fileName, mimeType;
  final DocumentKind kind;
  final DateTime createdAt;
  final Map<String, String> doctorName;
  // Null when the document belongs to the account holder.
  final String? familyMemberId, familyMemberName;
}
