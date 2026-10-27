enum FamilyRelationship { child, spouse, parent, sibling, other }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.dateOfBirth,
  });
  final String id, fullName;
  final FamilyRelationship relationship;
  final DateTime? dateOfBirth;
}
