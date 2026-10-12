import '../../../../core/catalog/scoped_resource_cubit.dart';
import '../../domain/entities/specialty_detail.dart';
import '../../domain/usecases/load_specialties.dart';

class SpecialtyDetailCubit extends ScopedResourceCubit<SpecialtyDetail> {
  SpecialtyDetailCubit(super.scope, this.load);
  final LoadSpecialties load;
  Future<void> get(String clinic, String id, String locale) =>
      fetch(clinic, (token) => load.detail(clinic, id, token, locale: locale));
}
