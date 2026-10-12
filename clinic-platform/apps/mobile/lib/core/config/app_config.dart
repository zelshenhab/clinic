import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.apiUrl,
    this.supabaseUrl = '',
    this.anonKey = '',
    this.smsEnabled = false,
  });
  final String apiUrl, supabaseUrl, anonKey;
  final bool smsEnabled;
  bool get authConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
  bool get developmentBrowsing =>
      !kReleaseMode && (!smsEnabled || !authConfigured);
  static const environment = AppConfig(
    apiUrl: String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://10.0.2.2:3000/api/v1',
    ),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    smsEnabled: bool.fromEnvironment('SMS_ENABLED'),
  );
}
