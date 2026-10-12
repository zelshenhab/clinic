import '../../../../core/catalog/scoped_resource_cubit.dart';
import '../../domain/entities/doctor_detail.dart';
import '../../domain/usecases/load_doctors.dart';

class DoctorDetailCubit extends ScopedResourceCubit<DoctorDetail> {
  DoctorDetailCubit(super.scope, this.load);
  final LoadDoctors load;
  Future<void> get(String clinic, String id, String locale) =>
      fetch(clinic, (token) => load.detail(clinic, id, token, locale: locale));
}
