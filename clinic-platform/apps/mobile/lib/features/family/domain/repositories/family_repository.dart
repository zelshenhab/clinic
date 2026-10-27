import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/family_member.dart';

abstract interface class FamilyRepository {
  Future<List<FamilyMember>> list(RequestCancellation token);
  Future<FamilyMember> add(
    String fullName,
    FamilyRelationship relationship,
    DateTime? dateOfBirth,
  );
  Future<FamilyMember> update(
    String id,
    String fullName,
    FamilyRelationship relationship,
    DateTime? dateOfBirth,
  );
  Future<void> remove(String id);
}
