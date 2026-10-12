import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_page.dart';
import '../../../../core/catalog/catalog_parser.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/repositories/promotion_repository.dart';
import '../models/promotion_model.dart';

class ApiPromotionRepository implements PromotionRepository {
  ApiPromotionRepository(this.api);
  final ApiClient api;
  @override
  Future<CatalogPage<Promotion>> list(
    String clinicId,
    RequestCancellation token, {
    CatalogQuery query = const CatalogQuery(),
  }) async => CatalogParser.page(
    await api.get(
      query.path('/clinics/$clinicId/promotions'),
      cancelToken: token,
    ),
    (p) => PromotionModel.parse(p, clinicId),
  );
}
