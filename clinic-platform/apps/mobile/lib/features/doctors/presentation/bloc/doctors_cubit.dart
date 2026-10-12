import '../../../../core/catalog/catalog_list_cubit.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/usecases/load_doctors.dart';

class DoctorsCubit extends CatalogListCubit<Doctor> {
  DoctorsCubit(ClinicScope scope, LoadDoctors load) : super(scope, load.call);
}
