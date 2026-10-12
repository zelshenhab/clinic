import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/home_catalog.dart';

abstract interface class HomeRepository {
  Future<HomeCatalog> get(
    String clinicId,
    RequestCancellation token,
    String locale,
  );
}
