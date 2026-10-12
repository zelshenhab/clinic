import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:clinic_mobile/core/network/api_client.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:clinic_mobile/features/home/domain/entities/home_catalog.dart';
import 'package:clinic_mobile/features/home/domain/usecases/load_home.dart';
import 'package:clinic_mobile/features/home/presentation/bloc/home_cubit.dart';
import 'package:clinic_mobile/features/clinic_selection/domain/entities/clinic.dart';
import 'fakes.dart';

const doctorId = '12a30244-3000-4000-8000-000000000003';
const specialtyId = '12a30244-3000-4000-8000-000000000004';
const serviceId = '12a30244-3000-4000-8000-000000000005';
Map<String, String> translated(String ru, String en) => {'ru': ru, 'en': en};
Map<String, dynamic> clinicJson(Clinic clinic) => {
  'id': clinic.id,
  'name': clinic.name,
  'address': clinic.address,
  'description': clinic.description,
  'timezone': clinic.timezone,
  'working_hours': {'weekdays': '09:00–18:00'},
};
Map<String, dynamic> specialtyJson(String clinic) => {
  'id': specialtyId,
  'clinic_id': clinic,
  'name': translated('Терапия', 'General medicine'),
  'description': translated(
    'Заботимся о здоровье всей семьи',
    'Care for the whole family',
  ),
  'icon': 'medical',
  'doctor_count': 2,
  'sort_order': 0,
};
Map<String, dynamic> doctorJson(String clinic) => {
  'id': doctorId,
  'clinic_id': clinic,
  'name': translated(
    'Александра Константиновна Ветрова',
    'Alexandra Konstantinovna Vetrova',
  ),
  'description': translated('Консультации', 'Consultations'),
  'professional_title': translated('Врач-терапевт', 'Physician'),
  'experience_years': 12,
  'starting_price_rub': clinic == clinicA.id ? '2200.00' : '3100.00',
  'photo_url': null,
  'specialties': [
    {'id': specialtyId, 'name': translated('Терапия', 'General medicine')},
  ],
};
Map<String, dynamic> serviceJson(String clinic) => {
  'id': serviceId,
  'clinic_id': clinic,
  'specialty_id': specialtyId,
  'specialty_name': translated('Терапия', 'General medicine'),
  'name': translated(
    'Первичная консультация специалиста',
    'Initial specialist consultation',
  ),
  'description': translated(
    'Подробная консультация с разбором ваших вопросов',
    'A detailed consultation to discuss your concerns',
  ),
  'category_key': 'consultations',
  'category': translated('Консультации', 'Consultations'),
  'price_rub': clinic == clinicA.id ? '2200.00' : '3100.00',
  'duration_minutes': 30,
};
Map<String, dynamic> promotionJson(String clinic) => {
  'id': doctorId,
  'clinic_id': clinic,
  'title': translated(
    'Внимательная медицина для всей семьи',
    'Thoughtful medicine for the whole family',
  ),
  'description': translated(
    'Познакомьтесь с нашей командой и выберите специалиста для консультации.',
    'Meet our team and choose a specialist for your consultation.',
  ),
  'image_url': null,
  'action_kind': 'doctors',
};
Map<String, dynamic> pageJson(
  List<dynamic> items, {
  int page = 1,
  int? total,
  bool hasMore = false,
}) => {
  'items': items,
  'pagination': {
    'page': page,
    'limit': 12,
    'total': total ?? items.length,
    'hasMore': hasMore,
  },
};
Map<String, dynamic> doctorDetailJson(String clinic) => {
  ...doctorJson(clinic),
  'clinic': clinicJson(clinic == clinicA.id ? clinicA : clinicB),
  'education': translated(
    'Демонстрационный университет',
    'Fictional university',
  ),
  'biography': translated(
    'Внимательный подход к здоровью',
    'Thoughtful approach to health',
  ),
  'qualifications': translated(
    'Повышение квалификации',
    'Continuing education',
  ),
  'languages': ['ru', 'en'],
  'services': pageJson([serviceJson(clinic)]),
  'schedules': [
    {
      'weekday': 1,
      'starts_at': '09:00:00',
      'ends_at': '18:00:00',
      'breaks': [],
    },
  ],
};

class CatalogAdapter implements HttpClientAdapter {
  CatalogAdapter({this.responder});
  final (int, dynamic) Function(RequestOptions)? responder;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final clinic = options.uri.pathSegments.contains(clinicB.id)
        ? clinicB.id
        : clinicA.id;
    final path = options.uri.path;
    final (status, data) =
        responder?.call(options) ??
        (
          200,
          path.endsWith('/home')
              ? {
                  'clinic': clinicJson(
                    clinic == clinicA.id ? clinicA : clinicB,
                  ),
                  'promotions': [promotionJson(clinic)],
                  'doctors': [doctorJson(clinic)],
                  'specialties': [specialtyJson(clinic)],
                  'services': [serviceJson(clinic)],
                }
              : path.endsWith('/doctors/$doctorId')
              ? doctorDetailJson(clinic)
              : path.endsWith('/specialties/$specialtyId')
              ? {
                  ...specialtyJson(clinic),
                  'doctors': pageJson([doctorJson(clinic)]),
                  'services': pageJson([serviceJson(clinic)]),
                }
              : path.endsWith('/services/$serviceId')
              ? {
                  ...serviceJson(clinic),
                  'clinic': clinicJson(
                    clinic == clinicA.id ? clinicA : clinicB,
                  ),
                  'doctors': pageJson([doctorJson(clinic)]),
                }
              : path.endsWith('/booking-context')
              ? {
                  'clinic': clinicJson(
                    clinic == clinicA.id ? clinicA : clinicB,
                  ),
                  'doctor': doctorJson(clinic),
                  'service': serviceJson(clinic),
                  'specialty': specialtyJson(clinic),
                  'online_booking_enabled': false,
                }
              : path.endsWith('/doctors')
              ? pageJson([doctorJson(clinic)])
              : path.endsWith('/services')
              ? {
                  ...pageJson([serviceJson(clinic)]),
                  'categories': [
                    {
                      'category_key': 'consultations',
                      'category': translated('Консультации', 'Consultations'),
                    },
                  ],
                }
              : path.endsWith('/specialties')
              ? pageJson([specialtyJson(clinic)])
              : path.endsWith('/promotions')
              ? pageJson([promotionJson(clinic)])
              : [],
        );
    return ResponseBody.fromString(
      jsonEncode({'success': status == 200, 'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient catalogClient(CatalogAdapter adapter) {
  tz.initializeTimeZones();
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient('https://api.example.test', transport: dio);
}

class EmptyFixtureHomeRepository implements HomeRepository {
  @override
  Future<HomeCatalog> get(
    String clinic,
    RequestCancellation token,
    String locale,
  ) async => HomeCatalog(
    clinic: clinic == clinicA.id ? clinicA : clinicB,
    promotions: [],
    specialties: [],
    doctors: [],
    services: [],
  );
}

HomeCubit fixtureHomeCubit(ClinicScope scope) =>
    HomeCubit(scope, LoadHome(EmptyFixtureHomeRepository()));
