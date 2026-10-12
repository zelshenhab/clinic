import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../repositories/promotion_repository.dart';
import '../entities/promotion.dart';

class LoadPromotions {
  LoadPromotions(this.repository);
  final PromotionRepository repository;
  Future<CatalogPage<Promotion>> call(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) => repository.list(clinicId, token, query: query);
}
