import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/catalog_list_page.dart';
import '../../../../core/widgets/catalog_filters.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/catalog/catalog_list_cubit.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../../specialties/presentation/bloc/specialties_cubit.dart';
import '../../domain/entities/medical_service.dart';
import '../bloc/services_cubit.dart';
import '../widgets/service_card.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({
    super.key,
    required this.clinicId,
    this.query = const CatalogQuery(),
  });
  final String clinicId;
  final CatalogQuery query;
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
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
      builder: (context, specialties) =>
          CatalogListPage<MedicalService, ServicesCubit>(
            clinicId: widget.clinicId,
            title: t.services,
            empty: t.noSearchResults,
            searchLabel: t.searchServices,
            initialQuery: widget.query,
            itemBuilder: (s) =>
                ServiceCard(service: s, doctorId: widget.query.doctorId),
            filters: (state) => Column(
              children: [
                CatalogFilters(
                  sort: state.query.sort,
                  specialty: state.query.specialtyId,
                  specialties: {
                    for (final s in specialties.items)
                      s.id: localized(s.name, locale ?? 'ru'),
                  },
                  category: state.query.category,
                  categories: {
                    for (final e in state.categories.entries)
                      e.key: localized(e.value, locale ?? 'ru'),
                  },
                  onSort: (sort) => context.read<ServicesCubit>().filter(
                    state.query.copy(sort: sort),
                  ),
                  onSpecialty: (id) => context.read<ServicesCubit>().filter(
                    state.query.copy(
                      specialtyId: id,
                      clearSpecialty: id == null,
                    ),
                  ),
                  onCategory: (key) => context.read<ServicesCubit>().filter(
                    state.query.copy(category: key, clearCategory: key == null),
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
