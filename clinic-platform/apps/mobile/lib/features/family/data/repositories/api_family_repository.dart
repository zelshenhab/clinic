import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/repositories/family_repository.dart';

class ApiFamilyRepository implements FamilyRepository {
  ApiFamilyRepository(this.api);
  final ApiClient api;
  static const path = '/me/family-members';

  FamilyMember parse(dynamic value) {
    final row = CatalogParser.object(value), birth = row['date_of_birth'];
    return FamilyMember(
      id: CatalogParser.id(row['id']),
      fullName: row['full_name'] as String,
      relationship: FamilyRelationship.values.byName(
        row['relationship'] as String,
      ),
      dateOfBirth: birth == null ? null : DateTime.parse(birth as String),
    );
  }

  Map<String, dynamic> body(
    String fullName,
    FamilyRelationship relationship,
    DateTime? dateOfBirth,
  ) => {
    'full_name': fullName.trim(),
    'relationship': relationship.name,
    'date_of_birth': dateOfBirth == null
        ? null
        : DateFormat('yyyy-MM-dd').format(dateOfBirth),
  };

  @override
  Future<List<FamilyMember>> list(RequestCancellation token) async {
    final data = await api.get(path, private: true, cancelToken: token);
    return CatalogParser.safe(() => (data as List).map(parse).toList());
  }

  @override
  Future<FamilyMember> add(
    String fullName,
    FamilyRelationship relationship,
    DateTime? dateOfBirth,
  ) async {
    final data = await api.request(
      path,
      method: 'POST',
      private: true,
      body: body(fullName, relationship, dateOfBirth),
    );
    return CatalogParser.safe(() => parse(data));
  }

  @override
  Future<FamilyMember> update(
    String id,
    String fullName,
    FamilyRelationship relationship,
    DateTime? dateOfBirth,
  ) async {
    final data = await api.patch(
      '$path/$id',
      body(fullName, relationship, dateOfBirth),
    );
    return CatalogParser.safe(() => parse(data));
  }

  @override
  Future<void> remove(String id) async {
    await api.request('$path/$id', method: 'DELETE', private: true);
  }
}
