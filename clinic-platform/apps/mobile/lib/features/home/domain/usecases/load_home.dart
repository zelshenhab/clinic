import '../../../../core/cancellation/request_cancellation.dart';
import '../entities/home_catalog.dart';
import '../repositories/home_repository.dart';

class LoadHome {
  LoadHome(this.repository);
  final HomeRepository repository;
  Future<HomeCatalog> call(
    String clinicId,
    RequestCancellation token,
    String locale,
  ) => repository.get(clinicId, token, locale);
}
