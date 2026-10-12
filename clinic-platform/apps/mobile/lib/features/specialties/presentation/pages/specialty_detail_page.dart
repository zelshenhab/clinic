import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/catalog_detail_page.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/specialty_detail.dart';
import '../bloc/specialty_detail_cubit.dart';
import '../widgets/specialty_card.dart';
import '../../../doctors/presentation/widgets/doctor_card.dart';
import '../../../services/presentation/widgets/service_card.dart';

class SpecialtyDetailPage extends StatelessWidget {
  const SpecialtyDetailPage({
    super.key,
    required this.clinicId,
    required this.id,
  });
  final String clinicId, id;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return CatalogDetailPage<SpecialtyDetail, SpecialtyDetailCubit>(
      clinicId: clinicId,
      title: t.specialties,
      load: (c, l) => c.get(clinicId, id, l),
      content: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              specialtyIcon(data.specialty.icon),
              size: 40,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            localized(data.specialty.name, locale),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(localized(data.specialty.description, locale)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.relatedDoctors,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/doctors?specialtyId=$id'),
                child: Text(t.seeAll),
              ),
            ],
          ),
          if (data.doctors.items.isEmpty)
            AppEmptyState(title: t.noDoctors)
          else
            ...data.doctors.items.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DoctorCard(doctor: d),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.relatedServices,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/services?specialtyId=$id'),
                child: Text(t.seeAll),
              ),
            ],
          ),
          if (data.services.items.isEmpty)
            AppEmptyState(title: t.noSearchResults)
          else
            ...data.services.items.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ServiceCard(service: s),
              ),
            ),
          const SizedBox(height: 24),
          AppButton(
            label: t.bookAppointment,
            onPressed: () => context.push('/booking?specialtyId=$id'),
          ),
        ],
      ),
    );
  }
}
