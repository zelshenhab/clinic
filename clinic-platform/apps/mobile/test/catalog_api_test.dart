import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/core/catalog/catalog_query.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/core/localization/catalog_format.dart';
import 'package:clinic_mobile/features/doctors/data/repositories/api_doctor_repository.dart';
import 'package:clinic_mobile/features/services/data/repositories/api_service_repository.dart';
import 'package:clinic_mobile/features/specialties/data/repositories/api_specialty_repository.dart';
import 'package:clinic_mobile/features/home/data/repositories/api_home_repository.dart';
import 'package:clinic_mobile/features/appointments/data/repositories/api_booking_context_repository.dart';
import 'support/catalog_fixtures.dart';
import 'support/fakes.dart';

void main() {
  test(
    'doctor requests encode search, UUID filters, sorting and page metadata',
    () async {
      final adapter = CatalogAdapter(),
          repo = ApiDoctorRepository(catalogClient(adapter));
      final page = await repo.list(
        clinicB.id,
        RequestCancellation(),
        query: const CatalogQuery(
          search: 'Анна & 100%',
          specialtyId: specialtyId,
          sort: 'price_asc',
          locale: 'en',
          page: 2,
        ),
      );
      expect(page.items.single.clinicId, clinicB.id);
      final uri = adapter.requests.single.uri;
      expect(uri.queryParameters['search'], 'Анна & 100%');
      expect(uri.queryParameters['specialtyId'], specialtyId);
      expect(uri.queryParameters['page'], '2');
      expect(uri.queryParameters['sort'], 'price_asc');
    },
  );
  test(
    'prices are parsed from clinic data and formatted in RUB in both locales',
    () async {
      final repo = ApiServiceRepository(catalogClient(CatalogAdapter()));
      final a = await repo.list(clinicA.id, RequestCancellation()),
          b = await repo.list(clinicB.id, RequestCancellation());
      expect(a.items.single.price, 2200);
      expect(b.items.single.price, 3100);
      expect(a.categories['consultations']!['en'], 'Consultations');
      expect(rub(2200, 'ru'), contains('₽'));
      expect(rub(3100, 'en'), contains('₽'));
      expect(rub(2200, 'ru'), isNot(contains(r'$')));
    },
  );
  test(
    'doctor detail maps professional fields, services and schedule without slots',
    () async {
      final repo = ApiDoctorRepository(catalogClient(CatalogAdapter()));
      final d = await repo.detail(
        clinicA.id,
        doctorId,
        RequestCancellation(),
        locale: 'en',
      );
      expect(d.doctor.id, doctorId);
      expect(d.education['en'], 'Fictional university');
      expect(d.services.items.single.price, 2200);
      expect(d.schedules.single.weekday, 1);
      expect(d.languages, ['ru', 'en']);
    },
  );
  test(
    'home and specialty detail map clinic-specific related records',
    () async {
      final api = catalogClient(CatalogAdapter());
      final home = await ApiHomeRepository(
        api,
      ).get(clinicB.id, RequestCancellation(), 'ru');
      expect(home.clinic.id, clinicB.id);
      expect(home.promotions.single.clinicId, clinicB.id);
      expect(home.services.single.price, 3100);
      final specialty = await ApiSpecialtyRepository(
        api,
      ).detail(clinicB.id, specialtyId, RequestCancellation());
      expect(specialty.doctors.items.single.clinicId, clinicB.id);
      expect(specialty.services.items.single.clinicId, clinicB.id);
    },
  );
  test(
    'rejects cross-clinic rows, invalid UUIDs and malformed numeric values',
    () async {
      for (final row in [
        {...doctorJson(clinicB.id)},
        {...doctorJson(clinicA.id), 'id': 'clinic_001'},
        {...doctorJson(clinicA.id), 'starting_price_rub': 'NaN'},
      ]) {
        final repo = ApiDoctorRepository(
          catalogClient(
            CatalogAdapter(responder: (_) => (200, pageJson([row]))),
          ),
        );
        await expectLater(
          repo.list(clinicA.id, RequestCancellation()),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              FailureKind.invalidResponse,
            ),
          ),
        );
      }
    },
  );
  test(
    'a server failure produces a typed error and never a successful empty list',
    () async {
      final repo = ApiServiceRepository(
        catalogClient(CatalogAdapter(responder: (_) => (503, {}))),
      );
      await expectLater(
        repo.list(clinicA.id, RequestCancellation()),
        throwsA(
          isA<AppException>().having((e) => e.kind, 'kind', FailureKind.server),
        ),
      );
    },
  );
  test(
    'booking preparation parses validated selections and rejects success-shaped booking data',
    () async {
      final repo = ApiBookingContextRepository(catalogClient(CatalogAdapter()));
      final data = await repo.get(
        clinicA.id,
        const CatalogQuery(doctorId: doctorId, serviceId: serviceId),
        RequestCancellation(),
      );
      expect(data.doctor!.id, doctorId);
      expect(data.service!.id, serviceId);
      final bad = ApiBookingContextRepository(
        catalogClient(
          CatalogAdapter(
            responder: (_) => (
              200,
              {
                'clinic': clinicJson(clinicA),
                'online_booking_enabled': 'invalid',
              },
            ),
          ),
        ),
      );
      await expectLater(
        bad.get(clinicA.id, const CatalogQuery(), RequestCancellation()),
        throwsA(isA<AppException>()),
      );
    },
  );
}
