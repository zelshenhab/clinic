class AuthIdentity {
  const AuthIdentity(this.id, this.phone);
  final String id, phone;
}

class PatientProfile {
  const PatientProfile({required this.id, required this.fullName, this.email});
  final String id, fullName;
  final String? email;
  bool get complete => fullName.trim().length >= 2;
}
