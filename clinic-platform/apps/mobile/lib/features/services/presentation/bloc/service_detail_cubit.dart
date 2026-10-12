import '../../../../core/catalog/scoped_resource_cubit.dart';
import '../../domain/entities/service_detail.dart';
import '../../domain/usecases/load_services.dart';

class ServiceDetailCubit extends ScopedResourceCubit<ServiceDetail> {
  ServiceDetailCubit(super.scope, this.load);
  final LoadServices load;
  Future<void> get(String clinic, String id, String locale) =>
      fetch(clinic, (token) => load.detail(clinic, id, token, locale: locale));
}
