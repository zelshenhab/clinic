import '../../../../core/catalog/scoped_resource_cubit.dart';
import '../../domain/entities/home_catalog.dart';
import '../../domain/usecases/load_home.dart';

class HomeCubit extends ScopedResourceCubit<HomeCatalog> {
  HomeCubit(super.scope, this.load);
  final LoadHome load;
  Future<void> get(String clinic, String locale) =>
      fetch(clinic, (token) => load(clinic, token, locale));
}
