import '../../../../core/catalog/catalog_parser.dart';
import '../../domain/entities/doctor.dart';

class DoctorModel {
  static Doctor parse(dynamic data, String clinic) => CatalogParser.safe(() {
    final r = CatalogParser.object(data);
    CatalogParser.clinic(r, clinic);
    return Doctor(
      id: CatalogParser.id(r['id']),
      clinicId: clinic,
      name: CatalogParser.text(r['name']),
      description: CatalogParser.text(r['description']),
      title: CatalogParser.text(r['professional_title']),
      photoUrl: r['photo_url'] as String?,
      experienceYears: r['experience_years'] == null
          ? null
          : CatalogParser.integer(r['experience_years'], max: 80),
      startingPrice: r['starting_price_rub'] == null
          ? null
          : CatalogParser.price(r['starting_price_rub']),
      specialties: (r['specialties'] as List)
          .map(
            (s) => DoctorSpecialty(
              CatalogParser.id(s['id']),
              CatalogParser.text(s['name']),
            ),
          )
          .toList(),
    );
  });
}
