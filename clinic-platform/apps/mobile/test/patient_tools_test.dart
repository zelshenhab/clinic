import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/core/network/api_client.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/network/scoped_list_cubit.dart';
import 'package:clinic_mobile/core/localization/app_localizations.dart';
import 'package:clinic_mobile/features/appointments/data/repositories/api_patient_tools_repository.dart';
import 'package:clinic_mobile/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:clinic_mobile/features/appointments/domain/entities/appointment.dart';
import 'package:clinic_mobile/features/appointments/domain/usecases/load_appointments.dart';
import 'package:clinic_mobile/features/appointments/presentation/bloc/appointments_cubit.dart';
import 'package:clinic_mobile/features/appointments/presentation/pages/appointment_actions.dart';
import 'package:clinic_mobile/features/appointments/presentation/pages/patient_tools_pages.dart';
import 'booking_flow_test.dart' show BookingFake;
import 'network_test.dart' show QueueAdapter;

const clinic = '10000000-0000-4000-8000-000000000001',
    doctor = '10000000-0000-4000-8000-000000000002',
    service = '10000000-0000-4000-8000-000000000003',
    id = '10000000-0000-4000-8000-000000000004';

class AppointmentsFake implements AppointmentRepository {
  int calls = 0;
  @override
  Future<List<Appointment>> list(String c, RequestCancellation t) async {
    calls++;
    return [];
  }
}

ApiPatientToolsRepository repository(
  List<RequestOptions> calls, {
  bool Function()? fail,
  dynamic Function(RequestOptions)? respond,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, h) {
        calls.add(o);
        if (fail?.call() == true && o.method == 'PATCH') {
          h.reject(
            DioException(
              requestOptions: o,
              response: Response(
                requestOptions: o,
                statusCode: 409,
                data: {
                  'error': {'code': 'POLICY_CUTOFF'},
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        final data =
            respond?.call(o) ??
            (o.path.endsWith('booking-policy')
                ? {
                    'cancellation_notice_minutes': 120,
                    'reschedule_notice_minutes': 120,
                  }
                : o.uri.path.endsWith('next-available')
                ? {
                    'items': [
                      {
                        'clinic_id': clinic,
                        'doctor_id': doctor,
                        'service_id': service,
                        'doctor_name': {'ru': 'Врач', 'en': 'Doctor Test'},
                        'service_name': {'ru': 'Осмотр', 'en': 'Consultation'},
                        'starts_at': '2026-12-01T06:00:00Z',
                        'price_rub': 1000,
                      },
                    ],
                    'specialties': [],
                    'searched_until': '2026-12-01',
                    'combination_limit': false,
                  }
                : {});
        h.resolve(
          Response(
            requestOptions: o,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ),
        );
      },
    ),
  );
  return ApiPatientToolsRepository(ApiClient('', transport: dio));
}

Widget app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'patient writes carry versions and exact UTC times; nearest search stays public',
    () async {
      final calls = <RequestOptions>[],
          repo = repository(calls),
          version = DateTime.utc(2026, 10, 16),
          start = DateTime.utc(2026, 12, 1, 6);
      await repo.cancel(clinic, id, version);
      await repo.reschedule(clinic, id, version, start);
      await repo.joinWaitlist(clinic, doctor, service, '2026-12-01');
      await repo.nearest(clinic, null, RequestCancellation());
      expect(calls[0].data, {
        'status': 'cancelled',
        'expected_updated_at': version.toIso8601String(),
      });
      expect(calls[1].data, {
        'starts_at': start.toIso8601String(),
        'expected_updated_at': version.toIso8601String(),
      });
      expect(calls.take(3).every((o) => o.extra['private'] == true), true);
      expect(calls.last.extra['private'], false);
      expect(
        calls.take(3).every((o) => !(o.data as Map).containsKey('patient_id')),
        true,
      );
    },
  );
  test(
    'policy cutoff has an actionable failure distinct from occupied slots',
    () async {
      final adapter = QueueAdapter([
            (
              409,
              {
                'success': false,
                'error': {'code': 'POLICY_CUTOFF'},
              },
            ),
          ]),
          dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
            ..httpClientAdapter = adapter;
      await expectLater(
        ApiPatientToolsRepository(
          ApiClient('', transport: dio),
        ).cancel(clinic, id, DateTime.now()),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.policyCutoff,
          ),
        ),
      );
    },
  );
  test('nearest results reject foreign-clinic data', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(
          Response(
            requestOptions: o,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'specialties': [],
                'items': [
                  {'clinic_id': doctor},
                ],
              },
            },
          ),
        ),
      ),
    );
    await expectLater(
      ApiPatientToolsRepository(
        ApiClient('', transport: dio),
      ).nearest(clinic, null, RequestCancellation()),
      throwsA(
        isA<AppException>().having(
          (e) => e.kind,
          'kind',
          FailureKind.invalidResponse,
        ),
      ),
    );
  });
  test(
    'private updates debounce refresh and detach on account reset',
    () async {
      final scope = ClinicScope(), events = StreamController<void>.broadcast();
      int reads = 0;
      final cubit = ScopedListCubit<String>(scope, (c, t) async {
        reads++;
        return [c];
      }, updates: (_) => events.stream);
      await cubit.load(clinic);
      events.add(null);
      events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(reads, 2);
      scope.invalidate();
      events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(reads, 2);
      expect(cubit.state.items, isEmpty);
      await cubit.close();
      await events.close();
    },
  );
  testWidgets(
    'cancellation requires confirmation and preserves appointment on policy failure',
    (tester) async {
      final calls = <RequestOptions>[], source = AppointmentsFake();
      bool fail = true;
      final tools = repository(calls, fail: () => fail),
          cubit = AppointmentsCubit(ClinicScope(), LoadAppointments(source));
      final a = Appointment(
        id: id,
        clinicId: clinic,
        doctorId: doctor,
        serviceId: service,
        startsAt: DateTime.utc(2026, 12, 1, 6),
        updatedAt: DateTime.utc(2026, 10, 16),
        status: 'confirmed',
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: app(
            AppointmentActions(
              appointment: a,
              tools: tools,
              booking: BookingFake(),
              timezone: 'Europe/Moscow',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancel appointment'));
      await tester.pumpAndSettle();
      expect(source.calls, 0);
      expect(find.textContaining('120 minutes'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel appointment'));
      await tester.pumpAndSettle();
      expect(source.calls, 0);
      expect(find.textContaining('notice period has passed'), findsOneWidget);
      fail = false;
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Cancel appointment'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel appointment'));
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );
  testWidgets('rescheduling submits chosen slot only after confirmation', (
    tester,
  ) async {
    final calls = <RequestOptions>[],
        a = Appointment(
          id: id,
          clinicId: clinic,
          doctorId: doctor,
          serviceId: service,
          startsAt: DateTime.utc(2026, 12, 1, 8),
          updatedAt: DateTime.utc(2026, 10, 16),
          status: 'confirmed',
        );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showDialog<bool>(
              context: ctx,
              builder: (_) => RescheduleDialog(
                appointment: a,
                tools: repository(calls),
                booking: BookingFake(),
                timezone: 'Europe/Moscow',
                minutes: 120,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('09:00'));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Reschedule appointment'),
    );
    await tester.pumpAndSettle();
    expect(calls.single.data, {
      'starts_at': '2026-12-01T06:00:00.000Z',
      'expected_updated_at': '2026-10-16T00:00:00.000Z',
    });
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets(
    'waitlist shows doctor and service and leaves only after a successful response',
    (tester) async {
      final calls = <RequestOptions>[];
      bool left = false;
      final tools = repository(
        calls,
        respond: (o) {
          if (o.method == 'DELETE') {
            left = true;
            return {};
          }
          if (o.uri.path.endsWith('/waitlist')) {
            return [
              {
                'id': id,
                'clinic_id': clinic,
                'doctor_id': doctor,
                'service_id': service,
                'day': '2026-12-01',
                'state': left ? 'cancelled' : 'waiting',
                'doctor_name': {'ru': 'Врач', 'en': 'Doctor Test'},
                'service_name': {'ru': 'Осмотр', 'en': 'Consultation'},
              },
            ];
          }
          return null;
        },
      );
      await tester.pumpWidget(
        app(WaitlistPage(clinicId: clinic, tools: tools)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Doctor Test'), findsOneWidget);
      expect(find.text('Consultation'), findsOneWidget);
      await tester.tap(find.text('Leave waitlist'));
      await tester.pumpAndSettle();
      expect(left, true);
      expect(find.text('Leave waitlist'), findsNothing);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(calls.every((o) => o.extra['private'] == true), true);
    },
  );
  for (final locale in ['en', 'ru']) {
    testWidgets(
      'nearest search opens correct booking date at 320px in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => NearestPage(
                clinicId: clinic,
                timezone: 'Europe/Moscow',
                tools: repository([]),
              ),
            ),
            GoRoute(
              path: '/booking',
              builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        final label = locale == 'en' ? 'Confirm booking' : 'Подтвердить запись';
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.textContaining('doctorId=$doctor'), findsOneWidget);
        expect(find.textContaining('date=2026-12-01'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      },
    );
  }
}
