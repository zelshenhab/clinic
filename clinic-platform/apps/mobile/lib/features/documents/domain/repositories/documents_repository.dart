import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/medical_document.dart';

abstract interface class DocumentsRepository {
  Future<List<MedicalDocument>> list(String clinic, RequestCancellation token);
  // A short-lived signed link; request a fresh one for every open.
  Future<Uri> link(String clinic, String id);
}
