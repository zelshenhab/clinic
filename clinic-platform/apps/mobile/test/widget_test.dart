import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:clinic_mobile/app/app.dart';
import 'package:clinic_mobile/core/config/app_config.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/localization/app_localizations.dart';
import 'package:clinic_mobile/core/theme/app_theme.dart';
import 'package:clinic_mobile/features/clinic_selection/presentation/bloc/clinic_cubit.dart';
import 'package:clinic_mobile/features/clinic_selection/domain/usecases/load_clinics.dart';
import 'package:clinic_mobile/features/authentication/presentation/bloc/auth_cubit.dart';
import 'package:clinic_mobile/features/authentication/domain/usecases/auth_actions.dart';
import 'package:clinic_mobile/features/authentication/presentation/pages/login_page.dart';
import 'package:clinic_mobile/features/settings/presentation/bloc/locale_cubit.dart';
import 'package:clinic_mobile/features/settings/presentation/pages/settings_page.dart';
import 'support/fakes.dart';
import 'support/catalog_fixtures.dart';
import 'package:clinic_mobile/features/home/presentation/bloc/home_cubit.dart';

void main() {
  testWidgets(
    'new users see clinic selection and switch without old clinic content',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final di = GetIt.asNewInstance();
      final preferences = MemoryPreferences();
      final scope = ClinicScope();
      final fakeAuth = FakeAuth();
      final clinics = ClinicCubit(
        LoadClinics(FakeClinics()),
        preferences,
        scope,
      );
      final auth = AuthCubit(AuthActions(fakeAuth, FakeProfiles()), scope);
      di.registerFactory<HomeCubit>(() => fixtureHomeCubit(scope));
      di.registerSingleton<ClinicCubit>(clinics);
      di.registerSingleton<AuthCubit>(auth);
      di.registerSingleton<LocaleCubit>(LocaleCubit(preferences));
      di.registerSingleton<AppConfig>(
        const AppConfig(apiUrl: 'https://api.example.test'),
      );
      await tester.pumpWidget(ClinicApp(dependencies: di));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(find.text('Выберите вашу клинику'), findsOneWidget);
      await tester.tap(find.text('Выбрать клинику').first);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(find.text('Описание А'), findsOneWidget);
      await tester.tap(find.byTooltip('Сменить клинику'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      await tester.ensureVisible(find.text('Выбрать клинику').last);
      await tester.tap(find.text('Выбрать клинику').last);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(find.text('Описание Б'), findsOneWidget);
      expect(find.text('Описание А'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await clinics.close();
      await tester.runAsync(() async {
        await auth.close();
        await di<LocaleCubit>().close();
        await fakeAuth.events.close();
      });
    },
  );
  testWidgets('development flow is labeled and cannot send a pretend OTP', (
    tester,
  ) async {
    final auth = FakeAuth()..enabled = false;
    final cubit = AuthCubit(AuthActions(auth, FakeProfiles()), ClinicScope());
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: clinicTheme(),
          home: const LoginPage(
            config: AppConfig(apiUrl: 'https://api.example.test'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('Режим разработки · SMS не настроен'), findsOneWidget);
    expect(find.text('Получить код'), findsNothing);
    expect(auth.sends, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await cubit.close();
      await auth.events.close();
    });
  });
  testWidgets('language switching updates labels and persists the preference', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    final locale = LocaleCubit(preferences);
    await tester.pumpWidget(
      BlocProvider.value(
        value: locale,
        child: BlocBuilder<LocaleCubit, String>(
          builder: (context, code) => MaterialApp(
            locale: Locale(code),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: clinicTheme(),
            home: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('Настройки'), findsOneWidget);
    await tester.tap(find.text('Английский'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(preferences.read('language'), 'en');
    await tester.pumpWidget(const SizedBox());
    await locale.close();
  });
}
