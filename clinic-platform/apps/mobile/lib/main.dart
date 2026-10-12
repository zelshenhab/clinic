import 'package:flutter/material.dart';
import 'dart:ui';
import 'core/errors/app_diagnostics.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app/app.dart';
import 'app/di/dependencies.dart';
import 'core/config/app_config.dart';
import 'app/bootstrap/bootstrap_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  FlutterError.onError = (details) =>
      AppDiagnostics.report('flutter_error', details.exception);
  PlatformDispatcher.instance.onError = (error, stack) {
    AppDiagnostics.report('platform_error', error);
    return true;
  };
  try {
    final dependencies = await configureDependencies(AppConfig.environment);
    runApp(ClinicApp(dependencies: dependencies));
  } catch (error) {
    AppDiagnostics.report('bootstrap_error', error);
    runApp(BootstrapErrorApp(retry: main));
  }
}
