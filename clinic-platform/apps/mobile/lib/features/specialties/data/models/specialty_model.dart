import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/specialty.dart';

class SpecialtyModel {
  static Specialty parse(dynamic data, String clinic) => CatalogParser.safe(() {
    final r = CatalogParser.object(data);
    CatalogParser.clinic(r, clinic);
    return Specialty(
      id: CatalogParser.id(r['id']),
      clinicId: clinic,
      name: CatalogParser.text(r['name']),
      description: CatalogParser.text(r['description']),
      icon: r['icon'] as String,
      doctorCount: CatalogParser.integer(r['doctor_count']),
    );
  });
}
