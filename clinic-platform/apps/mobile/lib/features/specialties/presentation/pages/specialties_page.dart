import 'package:flutter/material.dart';
import '../../../../core/widgets/catalog_list_page.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/specialty.dart';
import '../bloc/specialties_cubit.dart';
import '../widgets/specialty_card.dart';

class SpecialtiesPage extends StatelessWidget {
  const SpecialtiesPage({super.key, required this.clinicId});
  final String clinicId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return CatalogListPage<Specialty, SpecialtiesCubit>(
      clinicId: clinicId,
      title: t.specialties,
      empty: t.noSpecialties,
      searchLabel: t.searchSpecialties,
      itemBuilder: (s) => SpecialtyCard(specialty: s),
    );
  }
}
