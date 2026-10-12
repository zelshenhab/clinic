import 'package:shared_preferences/shared_preferences.dart';
import '../errors/app_exception.dart';

abstract interface class Preferences {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class AppPreferences implements Preferences {
  AppPreferences(this.preferences);
  final SharedPreferences preferences;
  @override
  String? read(String key) => preferences.getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw const AppException(FailureKind.storage);
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!await preferences.remove(key)) {
      throw const AppException(FailureKind.storage);
    }
  }
}
