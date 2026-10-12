import 'package:url_launcher/url_launcher.dart';
import '../errors/app_exception.dart';

class ContactClinic {
  Future<void> call(String phone) async {
    if (!RegExp(r'^\+[0-9]{8,15}$').hasMatch(phone)) {
      throw const AppException(FailureKind.validation);
    }
    try {
      if (!await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      )) {
        throw const AppException(FailureKind.unknown);
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(FailureKind.unknown);
    }
  }
}
