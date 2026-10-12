import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../entities/booking_context.dart';

abstract interface class BookingContextRepository {
  Future<BookingContext> get(
    String clinicId,
    CatalogQuery query,
    RequestCancellation token,
  );
}
