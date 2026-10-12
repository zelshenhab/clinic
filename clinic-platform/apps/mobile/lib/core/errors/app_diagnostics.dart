import 'dart:convert';
import 'dart:developer' as developer;
import 'app_exception.dart';

/// Never logs exception text, stacks, request bodies, phone numbers, or tokens.
abstract final class AppDiagnostics {
  static void report(String event, Object error) {
    developer.log(
      jsonEncode({
        'event': event,
        'code': error is AppException ? error.kind.name : 'unknown',
      }),
      name: 'clinic',
    );
  }
}
