import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/clinic_selection/presentation/bloc/clinic_cubit.dart';
import '../features/authentication/presentation/bloc/auth_cubit.dart';
import '../features/settings/presentation/bloc/locale_cubit.dart';
import 'router/app_router.dart';
import '../core/utils/contact_clinic.dart';

class ClinicApp extends StatefulWidget {
  const ClinicApp({super.key, required this.dependencies});
  final GetIt dependencies;
  @override
  State<ClinicApp> createState() => _ClinicAppState();
}

class _ClinicAppState extends State<ClinicApp> {
  late final RouterRefresh refresh;
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    final di = widget.dependencies;
    refresh = RouterRefresh(di<ClinicCubit>(), di<AuthCubit>());
    router = createRouter(di, refresh);
    di<ClinicCubit>().load();
    di<AuthCubit>().restore();
  }

  @override
  void dispose() {
    router.dispose();
    refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final di = widget.dependencies;
    return RepositoryProvider<ContactClinic>(
      create: (_) => di<ContactClinic>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: di<ClinicCubit>()),
          BlocProvider.value(value: di<AuthCubit>()),
          BlocProvider.value(value: di<LocaleCubit>()),
        ],
        child: BlocBuilder<LocaleCubit, String>(
          builder: (context, language) => MaterialApp.router(
            routerConfig: router,
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)!.appTitle,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: clinicTheme(),
          ),
        ),
      ),
    );
  }
}
