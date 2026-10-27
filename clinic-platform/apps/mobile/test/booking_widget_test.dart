import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:clinic_mobile/core/localization/app_localizations.dart';
import 'package:clinic_mobile/core/catalog/catalog_query.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/features/appointments/presentation/pages/booking_slots.dart';
import 'package:clinic_mobile/features/appointments/presentation/bloc/booking_flow_cubit.dart';
import 'package:clinic_mobile/features/appointments/domain/entities/booking_context.dart';
import 'package:clinic_mobile/features/authentication/presentation/bloc/auth_cubit.dart';
import 'package:clinic_mobile/features/authentication/domain/entities/auth_identity.dart';
import 'package:clinic_mobile/features/authentication/domain/usecases/auth_actions.dart';
import 'package:clinic_mobile/features/doctors/data/models/doctor_model.dart';
import 'package:clinic_mobile/features/services/data/models/service_model.dart';
import 'support/fakes.dart';
import 'support/catalog_fixtures.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/features/family/domain/entities/family_member.dart';
import 'package:clinic_mobile/features/family/domain/repositories/family_repository.dart';
import 'booking_flow_test.dart' show BookingFake, UpdatesFake;

class FamilyFake implements FamilyRepository {
  @override
  Future<List<FamilyMember>> list(RequestCancellation token) async => const [
    FamilyMember(
      id: 'member-1',
      fullName: 'Fictional child',
      relationship: FamilyRelationship.child,
    ),
  ];
  @override
  Future<FamilyMember> add(String n, FamilyRelationship r, DateTime? b) =>
      throw UnimplementedError();
  @override
  Future<FamilyMember> update(
    String id,
    String n,
    FamilyRelationship r,
    DateTime? b,
  ) => throw UnimplementedError();
  @override
  Future<void> remove(String id) => throw UnimplementedError();
}

void main() {
  for (final language in ['ru', 'en']) {
    testWidgets(
      'slot selection and confirmed booking render on 320px in $language',
      (tester) async {
        tz.initializeTimeZones();
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scope = ClinicScope(),
            repo = BookingFake(),
            updates = UpdatesFake(),
            flow = BookingFlowCubit(scope, repo, updates),
            authSource = FakeAuth()
              ..identity = const AuthIdentity('patient', '+70000000000'),
            profiles = FakeProfiles()
              ..profile = const PatientProfile(
                id: 'patient',
                fullName: 'Test patient',
              ),
            auth = AuthCubit(AuthActions(authSource, profiles), scope);
        await auth.restore();
        final data = BookingContext(
          clinicA,
          DoctorModel.parse(doctorJson(clinicA.id), clinicA.id),
          ServiceModel.parse(serviceJson(clinicA.id), clinicA.id),
          null,
        );
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: flow),
            ],
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: BookingSlots(
                    data: data,
                    query: const CatalogQuery(),
                    family: FamilyFake(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('09:00'), findsOneWidget);
        await tester.tap(find.text('09:00'));
        await tester.pump();
        final label = language == 'ru'
            ? 'Подтвердить запись'
            : 'Confirm booking';
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(repo.bookings, 0);
        await tester.tap(find.text('Fictional child'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, label).last);
        await tester.pumpAndSettle();
        expect(repo.bookings, 1);
        expect(
          find.text(
            language == 'ru'
                ? 'Запись успешно создана'
                : 'Appointment booked successfully',
          ),
          findsOneWidget,
        );
        expect(repo.bookedFor, 'member-1');
        expect(
          find.text(
            language == 'ru'
                ? 'Пациент: Fictional child'
                : 'For: Fictional child',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            language == 'ru' ? 'Добавить в календарь' : 'Add to calendar',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await flow.close();
          await auth.close();
          await updates.controller.close();
          await authSource.events.close();
        });
      },
    );
  }
}
