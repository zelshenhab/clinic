import '../../../../core/catalog/catalog_list_cubit.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/medical_service.dart';
import '../../domain/usecases/load_services.dart';

class ServicesCubit extends CatalogListCubit<MedicalService> {
  ServicesCubit(ClinicScope scope, LoadServices load) : super(scope, load.call);
}
