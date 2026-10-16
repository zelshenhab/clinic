import '../../../../core/network/api_client.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../domain/repositories/patient_tools_repository.dart';

class ApiPatientToolsRepository implements PatientToolsRepository {
  ApiPatientToolsRepository(this.api);
  final ApiClient api;
  String base(String clinic) => '/clinics/$clinic/booking';
  @override
  Future<BookingPolicy> policy(String clinic) async {
    final data = await api.get('/clinics/$clinic/booking-policy');
    return CatalogParser.safe(
      () => BookingPolicy(
        CatalogParser.integer(data['cancellation_notice_minutes'], max: 10080),
        CatalogParser.integer(data['reschedule_notice_minutes'], max: 10080),
      ),
    );
  }

  @override
  Future<void> cancel(String clinic, String id, DateTime version) async {
    await api.patch('${base(clinic)}/appointments/$id', {
      'status': 'cancelled',
      'expected_updated_at': version.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> reschedule(
    String clinic,
    String id,
    DateTime version,
    DateTime start,
  ) async {
    await api.request(
      '${base(clinic)}/appointments/$id/reschedule',
      method: 'POST',
      private: true,
      body: {
        'starts_at': start.toUtc().toIso8601String(),
        'expected_updated_at': version.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<WaitlistEntry>> waitlist(
    String clinic,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      '${base(clinic)}/waitlist',
      private: true,
      cancelToken: token,
    );
    return CatalogParser.safe(
      () => (data as List).map((v) {
        final row = CatalogParser.object(v);
        CatalogParser.clinic(row, clinic);
        return WaitlistEntry(
          id: CatalogParser.id(row['id']),
          doctorId: CatalogParser.id(row['doctor_id']),
          serviceId: CatalogParser.id(row['service_id']),
          day: row['day'] as String,
          state: row['state'] as String,
          doctorName: CatalogParser.text(row['doctor_name']),
          serviceName: CatalogParser.text(row['service_name']),
        );
      }).toList(),
    );
  }

  @override
  Future<void> joinWaitlist(
    String clinic,
    String doctor,
    String service,
    String day,
  ) async {
    await api.request(
      '${base(clinic)}/waitlist',
      method: 'POST',
      private: true,
      body: {'doctor_id': doctor, 'service_id': service, 'day': day},
    );
  }

  @override
  Future<void> leaveWaitlist(String clinic, String id) async {
    await api.request(
      '${base(clinic)}/waitlist/$id',
      method: 'DELETE',
      private: true,
    );
  }

  @override
  Future<void> readNotification(String clinic, String id) async {
    await api.patch('${base(clinic)}/notifications/$id', {'read': true});
  }

  @override
  Future<NearestResults> nearest(
    String clinic,
    String? specialty,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      Uri(
        path: '/clinics/$clinic/next-available',
        queryParameters: {'specialty_id': ?specialty},
      ).toString(),
      cancelToken: token,
    );
    return CatalogParser.safe(() {
      final specialties = <String, Map<String, String>>{};
      for (final s in data['specialties'] as List) {
        specialties[CatalogParser.id(s['id'])] = CatalogParser.text(s['name']);
      }
      final items = (data['items'] as List).map((v) {
        final row = CatalogParser.object(v);
        CatalogParser.clinic(row, clinic);
        return NearestAppointment(
          doctorId: CatalogParser.id(row['doctor_id']),
          serviceId: CatalogParser.id(row['service_id']),
          doctorName: CatalogParser.text(row['doctor_name']),
          serviceName: CatalogParser.text(row['service_name']),
          startsAt: DateTime.parse(row['starts_at'] as String).toUtc(),
          price: CatalogParser.price(row['price_rub']),
        );
      }).toList();
      return NearestResults(
        items,
        specialties,
        data['searched_until'] as String,
        data['combination_limit'] as bool,
      );
    });
  }
}
