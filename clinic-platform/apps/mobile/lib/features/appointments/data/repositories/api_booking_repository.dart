import '../../../../core/network/api_client.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../../domain/repositories/booking_repository.dart';

class ApiBookingRepository implements BookingRepository {
  ApiBookingRepository(this.api);
  final ApiClient api;
  DateTime instant(dynamic value) {
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const FormatException();
    }
    return DateTime.parse(value).toUtc();
  }

  @override
  Future<List<AvailableSlot>> availability(
    String clinic,
    String doctor,
    String service,
    String date,
    RequestCancellation token,
  ) async {
    final data = await api.get(
      Uri(
        path: '/clinics/$clinic/availability',
        queryParameters: {
          'doctor_id': doctor,
          'service_id': service,
          'date': date,
        },
      ).toString(),
      cancelToken: token,
    );
    return CatalogParser.safe(
      () => (data as List).map((value) {
        final row = CatalogParser.object(value),
            start = instant(row['starts_at']),
            end = instant(row['ends_at']);
        if (!end.isAfter(start)) throw const FormatException();
        return AvailableSlot(start, end);
      }).toList(),
    );
  }

  @override
  Future<BookingReceipt> book(
    String clinic,
    String doctor,
    String service,
    DateTime startsAt,
    RequestCancellation token,
  ) async {
    final data = await api.request(
      '/clinics/$clinic/booking/appointments',
      method: 'POST',
      private: true,
      cancelToken: token,
      body: {
        'doctor_id': doctor,
        'service_id': service,
        'starts_at': startsAt.toUtc().toIso8601String(),
      },
    );
    return CatalogParser.safe(() {
      final row = CatalogParser.object(data);
      CatalogParser.clinic(row, clinic);
      if (row['doctor_id'] != doctor ||
          row['service_id'] != service ||
          !instant(row['starts_at']).isAtSameMomentAs(startsAt) ||
          !['pending', 'confirmed'].contains(row['status'])) {
        throw const FormatException();
      }
      return BookingReceipt(
        id: CatalogParser.id(row['id']),
        startsAt: instant(row['starts_at']),
        status: row['status'] as String,
        price: CatalogParser.price(row['price_rub']),
      );
    });
  }
}
