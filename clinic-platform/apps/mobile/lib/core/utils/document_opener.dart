import 'package:url_launcher/url_launcher.dart';
import '../errors/app_exception.dart';

// Hands the signed link to the system viewer, which can display, share or save the file.
class DocumentOpener {
  const DocumentOpener();
  Future<void> open(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const AppException(FailureKind.unknown);
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(FailureKind.unknown);
    }
  }
}
