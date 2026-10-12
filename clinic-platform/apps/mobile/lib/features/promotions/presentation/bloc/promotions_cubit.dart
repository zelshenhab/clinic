import '../../../../core/catalog/catalog_list_cubit.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/usecases/load_promotions.dart';

class PromotionsCubit extends CatalogListCubit<Promotion> {
  PromotionsCubit(ClinicScope scope, LoadPromotions load)
    : super(scope, load.call);
}
