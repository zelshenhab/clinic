import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/promotion.dart';

class PromotionModel {
  static Promotion parse(dynamic data, String clinic) => CatalogParser.safe(() {
    final r = CatalogParser.object(data);
    CatalogParser.clinic(r, clinic);
    final action = r['action_kind'] as String?;
    if (action != null &&
        !['doctors', 'specialties', 'services'].contains(action)) {
      throw const FormatException();
    }
    return Promotion(
      id: CatalogParser.id(r['id']),
      clinicId: clinic,
      title: CatalogParser.text(r['title']),
      description: CatalogParser.text(r['description']),
      imageUrl: r['image_url'] as String?,
      action: action,
    );
  });
}
