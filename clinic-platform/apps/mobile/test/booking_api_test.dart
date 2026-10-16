import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:clinic_mobile/core/network/api_client.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/appointments/data/repositories/api_booking_repository.dart';

const c = '10000000-0000-4000-8000-000000000001',
    d = '10000000-0000-4000-8000-000000000002',
    s = '10000000-0000-4000-8000-000000000003',
    id = '10000000-0000-4000-8000-000000000004';
void main() {
  test(
    'slot reads are public and booking sends exact UTC without a patient id',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      final calls = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': o.method == 'POST'
                      ? {
                          'id': id,
                          'clinic_id': c,
                          'doctor_id': d,
                          'service_id': s,
                          'starts_at': '2026-12-01T06:00:00Z',
                          'status': 'pending',
                          'price_rub': 1000,
                        }
                      : [
                          {
                            'starts_at': '2026-12-01T06:00:00Z',
                            'ends_at': '2026-12-01T06:30:00Z',
                          },
                        ],
                },
              ),
            );
          },
        ),
      );
      final repo = ApiBookingRepository(ApiClient('', transport: dio));
      final slots = await repo.availability(
        c,
        d,
        s,
        '2026-12-01',
        RequestCancellation(),
      );
      final receipt = await repo.book(
        c,
        d,
        s,
        slots.first.startsAt,
        RequestCancellation(),
      );
      expect(calls.first.extra['private'], false);
      expect(calls.last.extra['private'], true);
      expect((calls.last.data as Map).keys.toSet(), {
        'doctor_id',
        'service_id',
        'starts_at',
      });
      expect(receipt.id, id);
    },
  );
  test('mismatched committed bookings are rejected', () async {
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
                'id': id,
                'clinic_id': d,
                'doctor_id': d,
                'service_id': s,
                'starts_at': '2026-12-01T06:00:00Z',
                'status': 'pending',
                'price_rub': 1000,
              },
            },
          ),
        ),
      ),
    );
    await expectLater(
      ApiBookingRepository(
        ApiClient('', transport: dio),
      ).book(c, d, s, DateTime.utc(2026, 12, 1, 6), RequestCancellation()),
      throwsA(isA<AppException>()),
    );
  });
}
