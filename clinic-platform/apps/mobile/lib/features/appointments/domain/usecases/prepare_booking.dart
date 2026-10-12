import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/booking_context.dart';
import '../repositories/booking_context_repository.dart';

class PrepareBooking {
  PrepareBooking(this.repository);
  final BookingContextRepository repository;
  Future<BookingContext> call(
    String clinicId,
    CatalogQuery query,
    RequestCancellation token,
  ) => repository.get(clinicId, query, token);
}
