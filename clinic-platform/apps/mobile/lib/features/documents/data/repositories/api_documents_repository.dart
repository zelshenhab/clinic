import '../../../../core/network/api_client.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../domain/entities/medical_document.dart';
import '../../domain/repositories/documents_repository.dart';

class ApiDocumentsRepository implements DocumentsRepository {
  ApiDocumentsRepository(this.api);
  final ApiClient api;
  static const kinds = {
    'report': DocumentKind.report,
    'lab_result': DocumentKind.labResult,
    'imaging': DocumentKind.imaging,
    'prescription': DocumentKind.prescription,
    'other': DocumentKind.other,
  };

  @override
  Future<List<MedicalDocument>> list(
    String clinic,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      '/clinics/$clinic/medical-records',
      private: true,
      cancelToken: token,
    );
    return CatalogParser.safe(
      () => (data as List).map((value) {
        final row = CatalogParser.object(value);
        CatalogParser.clinic(row, clinic);
        return MedicalDocument(
          id: CatalogParser.id(row['id']),
          kind: kinds[row['kind']]!,
          title: row['title'] as String,
          fileName: row['file_name'] as String,
          mimeType: row['mime_type'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
          doctorName: row['doctor_name'] == null
              ? const {}
              : CatalogParser.text(row['doctor_name']),
          familyMemberId: row['family_member_id'] as String?,
          familyMemberName: row['family_member_name'] as String?,
        );
      }).toList(),
    );
  }

  @override
  Future<Uri> link(String clinic, String id) async {
    final data = await api.get(
      '/clinics/$clinic/medical-records/$id/download',
      private: true,
    );
    return CatalogParser.safe(() {
      final url = Uri.parse(CatalogParser.object(data)['url'] as String);
      if (!['https', 'http'].contains(url.scheme) || url.host.isEmpty) {
        throw const FormatException();
      }
      return url;
    });
  }
}
