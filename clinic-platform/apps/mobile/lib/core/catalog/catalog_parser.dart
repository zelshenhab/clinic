import '../errors/app_exception.dart';
import 'catalog_page.dart';

abstract final class CatalogParser {
  static T safe<T>(T Function() work) {
    try {
      return work();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(FailureKind.invalidResponse);
    }
  }

  static Map<String, dynamic> object(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  static Map<String, String> text(dynamic value) {
    final text = Map<String, String>.from(value as Map);
    if (!text.containsKey('ru') || !text.containsKey('en')) {
      throw const AppException(FailureKind.invalidResponse);
    }
    return text;
  }

  static String id(dynamic value) {
    if (value is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      throw const AppException(FailureKind.invalidResponse);
    }
    return value;
  }

  static void clinic(Map<String, dynamic> row, String expected) {
    if (id(row['clinic_id']) != expected) {
      throw const AppException(FailureKind.invalidResponse);
    }
  }

  static int integer(dynamic value, {int min = 0, int? max}) {
    if (value is! int || value < min || (max != null && value > max)) {
      throw const AppException(FailureKind.invalidResponse);
    }
    return value;
  }

  static String time(dynamic value) {
    if (value is! String ||
        !RegExp(
          r'^(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9](?:\.[0-9]+)?)?$',
        ).hasMatch(value)) {
      throw const AppException(FailureKind.invalidResponse);
    }
    return value;
  }

  static double price(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.parse(value as String);
    if (!parsed.isFinite || parsed < 0) {
      throw const AppException(FailureKind.invalidResponse);
    }
    return parsed;
  }

  static CatalogPage<T> page<T>(dynamic data, T Function(dynamic) parse) =>
      safe(() {
        final row = object(data), pagination = object(row['pagination']);
        final categories = <String, Map<String, String>>{};
        for (final category in row['categories'] as List? ?? []) {
          categories[category['category_key'] as String] = text(
            category['category'],
          );
        }
        return CatalogPage(
          items: (row['items'] as List).map(parse).toList(),
          page: integer(pagination['page'], min: 1),
          total: integer(pagination['total']),
          hasMore: pagination['hasMore'] as bool,
          categories: categories,
        );
      });
}
