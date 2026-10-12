import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:clinic_mobile/app/app.dart';
import 'package:clinic_mobile/core/config/app_config.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/localization/app_localizations.dart';
import 'package:clinic_mobile/core/theme/app_theme.dart';
import 'package:clinic_mobile/core/widgets/app_components.dart';
import 'package:clinic_mobile/core/widgets/app_skeleton.dart';
import 'package:clinic_mobile/core/utils/contact_clinic.dart';
import 'package:clinic_mobile/features/home/data/repositories/api_home_repository.dart';
import 'package:clinic_mobile/features/home/domain/usecases/load_home.dart';
import 'package:clinic_mobile/features/home/presentation/bloc/home_cubit.dart';
import 'package:clinic_mobile/features/home/presentation/pages/home_page.dart';
import 'package:clinic_mobile/features/doctors/data/repositories/api_doctor_repository.dart';
import 'package:clinic_mobile/features/doctors/domain/usecases/load_doctors.dart';
import 'package:clinic_mobile/features/doctors/presentation/bloc/doctors_cubit.dart';
import 'package:clinic_mobile/features/doctors/presentation/bloc/doctor_detail_cubit.dart';
import 'package:clinic_mobile/features/specialties/data/repositories/api_specialty_repository.dart';
import 'package:clinic_mobile/features/specialties/domain/usecases/load_specialties.dart';
import 'package:clinic_mobile/features/specialties/presentation/bloc/specialties_cubit.dart';
import 'package:clinic_mobile/features/specialties/presentation/bloc/specialty_detail_cubit.dart';
import 'package:clinic_mobile/features/services/data/repositories/api_service_repository.dart';
import 'package:clinic_mobile/features/services/domain/usecases/load_services.dart';
import 'package:clinic_mobile/features/services/presentation/bloc/services_cubit.dart';
import 'package:clinic_mobile/features/services/presentation/bloc/service_detail_cubit.dart';
import 'package:clinic_mobile/features/promotions/data/repositories/api_promotion_repository.dart';
import 'package:clinic_mobile/features/promotions/domain/usecases/load_promotions.dart';
import 'package:clinic_mobile/features/promotions/presentation/bloc/promotions_cubit.dart';
import 'package:clinic_mobile/features/appointments/data/repositories/api_booking_context_repository.dart';
import 'package:clinic_mobile/features/appointments/domain/usecases/prepare_booking.dart';
import 'package:clinic_mobile/features/appointments/presentation/bloc/booking_entry_cubit.dart';
import 'package:clinic_mobile/features/clinic_selection/presentation/bloc/clinic_cubit.dart';
import 'package:clinic_mobile/features/clinic_selection/domain/usecases/load_clinics.dart';
import 'package:clinic_mobile/features/authentication/presentation/bloc/auth_cubit.dart';
import 'package:clinic_mobile/features/authentication/domain/usecases/auth_actions.dart';
import 'package:clinic_mobile/features/settings/presentation/bloc/locale_cubit.dart';
import 'support/fakes.dart';
import 'support/catalog_fixtures.dart';

void main() {
  for (final language in ['ru', 'en']) {
    testWidgets('home and every catalog route render on 320px in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final di = GetIt.asNewInstance(),
          scope = ClinicScope(),
          preferences = MemoryPreferences();
      await preferences.write('language', language);
      final authRepository = FakeAuth();
      final auth = AuthCubit(
        AuthActions(authRepository, FakeProfiles()),
        scope,
      );
      final clinics = ClinicCubit(
        LoadClinics(FakeClinics()),
        preferences,
        scope,
      );
      final api = catalogClient(CatalogAdapter());
      final doctors = LoadDoctors(ApiDoctorRepository(api)),
          specialties = LoadSpecialties(ApiSpecialtyRepository(api)),
          services = LoadServices(ApiServiceRepository(api));
      di.registerSingleton<ClinicCubit>(clinics);
      di.registerSingleton<AuthCubit>(auth);
      di.registerSingleton<LocaleCubit>(LocaleCubit(preferences));
      di.registerSingleton<AppConfig>(
        const AppConfig(apiUrl: 'https://api.example.test'),
      );
      di.registerSingleton<ContactClinic>(ContactClinic());
      di.registerFactory<HomeCubit>(
        () => HomeCubit(scope, LoadHome(ApiHomeRepository(api))),
      );
      di.registerFactory<DoctorsCubit>(() => DoctorsCubit(scope, doctors));
      di.registerFactory<DoctorDetailCubit>(
        () => DoctorDetailCubit(scope, doctors),
      );
      di.registerFactory<SpecialtiesCubit>(
        () => SpecialtiesCubit(scope, specialties),
      );
      di.registerFactory<SpecialtyDetailCubit>(
        () => SpecialtyDetailCubit(scope, specialties),
      );
      di.registerFactory<ServicesCubit>(() => ServicesCubit(scope, services));
      di.registerFactory<ServiceDetailCubit>(
        () => ServiceDetailCubit(scope, services),
      );
      di.registerFactory<PromotionsCubit>(
        () =>
            PromotionsCubit(scope, LoadPromotions(ApiPromotionRepository(api))),
      );
      di.registerFactory<BookingEntryCubit>(
        () => BookingEntryCubit(
          scope,
          PrepareBooking(ApiBookingContextRepository(api)),
        ),
      );
      await tester.pumpWidget(ClinicApp(dependencies: di));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(language == 'ru' ? 'Выбрать клинику' : 'Select clinic').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(language == 'ru' ? 'Выбрать клинику' : 'Select clinic').first,
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(HomePage));
      final router = GoRouter.of(context);
      final t = AppLocalizations.of(context)!;
      expect(find.text(t.guestGreeting), findsOneWidget);
      expect(
        t.searchDoctors,
        language == 'ru' ? 'Поиск по имени врача' : 'Search doctors by name',
      );
      for (final route in [
        '/doctors?specialtyId=$specialtyId',
        '/doctors/$doctorId',
        '/specialties',
        '/specialties/$specialtyId',
        '/services?doctorId=$doctorId',
        '/services/$serviceId',
        '/promotions',
        '/booking?doctorId=$doctorId&serviceId=$serviceId',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        expect(find.byType(AppErrorView), findsNothing, reason: route);
        expect(find.byType(AppSkeleton), findsNothing, reason: route);
        final list = find.byType(Scrollable).first;
        if (list.evaluate().isNotEmpty) {
          await tester.drag(list, const Offset(0, -480));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'scroll $route');
        }
      }
      router.go('/home');
      await tester.pumpAndSettle();
      await clinics.select(clinicB);
      router.go('/home');
      await tester.pumpAndSettle();
      expect(di<ClinicCubit>().state.selected!.id, clinicB.id);
      expect(
        find.text(language == 'ru' ? 'Клиника Б' : 'Clinic B'),
        findsWidgets,
      );
      expect(
        find.text(language == 'ru' ? 'Клиника А' : 'Clinic A'),
        findsNothing,
      );
      router.go('/notifications');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['from'],
        'notifications',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await clinics.close();
        await auth.close();
        await di<LocaleCubit>().close();
        await authRepository.events.close();
      });
    });
  }
  testWidgets('home network error offers a working retry', (tester) async {
    var fail = true;
    final api = catalogClient(
      CatalogAdapter(
        responder: (_) => fail
            ? (503, {})
            : (
                200,
                {
                  'clinic': clinicJson(clinicA),
                  'promotions': [],
                  'specialties': [],
                  'doctors': [],
                  'services': [],
                },
              ),
      ),
    );
    final scope = ClinicScope();
    final home = HomeCubit(scope, LoadHome(ApiHomeRepository(api))),
        authRepository = FakeAuth();
    final auth = AuthCubit(AuthActions(authRepository, FakeProfiles()), scope);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: home),
          BlocProvider.value(value: auth),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: clinicTheme(),
          home: const Scaffold(body: HomePage(clinic: clinicA)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Описание А'), findsNothing);
    fail = false;
    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(find.text('Описание А'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await home.close();
      await auth.close();
      await authRepository.events.close();
    });
  });
}
