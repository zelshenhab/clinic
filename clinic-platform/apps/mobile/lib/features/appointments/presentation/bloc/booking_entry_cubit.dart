import '../../../../core/catalog/scoped_resource_cubit.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../domain/entities/booking_context.dart';
import '../../domain/usecases/prepare_booking.dart';

class BookingEntryCubit extends ScopedResourceCubit<BookingContext> {
  BookingEntryCubit(super.scope, this.prepare);
  final PrepareBooking prepare;
  Future<void> get(String clinic, CatalogQuery query) =>
      fetch(clinic, (token) => prepare(clinic, query, token));
}
