import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/medical_service.dart';

class ServiceModel {
  static MedicalService parse(dynamic data, String clinic) =>
      CatalogParser.safe(() {
        final r = CatalogParser.object(data);
        CatalogParser.clinic(r, clinic);
        return MedicalService(
          id: CatalogParser.id(r['id']),
          clinicId: clinic,
          specialtyId: CatalogParser.id(r['specialty_id']),
          name: CatalogParser.text(r['name']),
          description: CatalogParser.text(r['description']),
          specialtyName: CatalogParser.text(r['specialty_name']),
          category: CatalogParser.text(r['category']),
          categoryKey: r['category_key'] as String,
          price: CatalogParser.price(r['price_rub']),
          duration: CatalogParser.integer(
            r['duration_minutes'],
            min: 5,
            max: 480,
          ),
        );
      });
}
