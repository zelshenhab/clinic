import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/catalog_list_page.dart';
import '../../../../core/widgets/catalog_filters.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../../specialties/presentation/bloc/specialties_cubit.dart';
import '../bloc/doctors_cubit.dart';
import '../widgets/doctor_card.dart';
import '../../domain/entities/doctor.dart';
import '../../../../core/catalog/catalog_list_cubit.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({
    super.key,
    required this.clinicId,
    this.query = const CatalogQuery(),
  });
  final String clinicId;
  final CatalogQuery query;
  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  String? locale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final value = Localizations.localeOf(context).languageCode;
    if (locale != value) {
      locale = value;
      context.read<SpecialtiesCubit>().load(
        widget.clinicId,
        query: CatalogQuery(limit: 100, locale: value),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<SpecialtiesCubit, CatalogListState<Specialty>>(
      builder: (context, specialties) => CatalogListPage<Doctor, DoctorsCubit>(
        clinicId: widget.clinicId,
        title: t.doctors,
        empty: t.noDoctors,
        searchLabel: t.searchDoctors,
        initialQuery: widget.query,
        scaffold: false,
        itemBuilder: (d) =>
            DoctorCard(doctor: d, serviceId: widget.query.serviceId),
        filters: (state) => Column(
          children: [
            CatalogFilters(
              sort: state.query.sort,
              doctors: true,
              specialty: state.query.specialtyId,
              specialties: {
                for (final s in specialties.items)
                  s.id: localized(s.name, locale ?? 'ru'),
              },
              onSort: (sort) => context.read<DoctorsCubit>().filter(
                state.query.copy(sort: sort),
              ),
              onSpecialty: (id) => context.read<DoctorsCubit>().filter(
                state.query.copy(specialtyId: id, clearSpecialty: id == null),
              ),
            ),
            if (specialties.failure != null)
              AppErrorView(
                message: failureMessage(t, specialties.failure),
                retry: () => context.read<SpecialtiesCubit>().load(
                  widget.clinicId,
                  query: CatalogQuery(limit: 100, locale: locale ?? 'ru'),
                  force: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
