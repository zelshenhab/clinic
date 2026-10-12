import '../../../../core/catalog/catalog_list_cubit.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/specialty.dart';
import '../../domain/usecases/load_specialties.dart';

class SpecialtiesCubit extends CatalogListCubit<Specialty> {
  SpecialtiesCubit(ClinicScope scope, LoadSpecialties load)
    : super(scope, load.call);
}
