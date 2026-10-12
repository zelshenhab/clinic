import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_components.dart';
import '../../core/theme/app_theme.dart';

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.retry});
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: clinicTheme(),
    home: Builder(
      builder: (context) => AppScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorView(
              message: AppLocalizations.of(context)!.storageError,
              retry: retry,
            ),
          ),
        ),
      ),
    ),
  );
}
