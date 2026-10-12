import '../../../../core/errors/app_exception.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/clinic.dart';

class ClinicModel {
  static Clinic parse(dynamic json) {
    try {
      if (json is! Map<String, dynamic> ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(json['id'] as String)) {
        throw const FormatException();
      }
      Map<String, String> text(String key) {
        final value = Map<String, String>.from(json[key] as Map);
        if (value['ru'] == null || value['en'] == null) {
          throw const FormatException();
        }
        return value;
      }

      tz.getLocation(json['timezone'] as String);
      return Clinic(
        id: json['id'] as String,
        name: text('name'),
        address: text('address'),
        description: text('description'),
        timezone: json['timezone'] as String,
        imageUrl: json['image_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        phone: json['phone'] as String?,
        workingHours: Map<String, dynamic>.from(
          json['working_hours'] as Map? ?? {},
        ),
      );
    } catch (_) {
      throw const AppException(FailureKind.invalidResponse);
    }
  }
}
