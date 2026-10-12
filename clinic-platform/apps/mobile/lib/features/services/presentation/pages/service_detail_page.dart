import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/catalog_detail_page.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/service_detail.dart';
import '../bloc/service_detail_cubit.dart';
import '../../../doctors/presentation/widgets/doctor_card.dart';

class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({
    super.key,
    required this.clinicId,
    required this.id,
    this.doctorId,
  });
  final String clinicId, id;
  final String? doctorId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return CatalogDetailPage<ServiceDetail, ServiceDetailCubit>(
      clinicId: clinicId,
      title: t.serviceDetails,
      load: (c, l) => c.get(clinicId, id, l),
      content: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(data.service.category, locale).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          Text(
            localized(data.service.name, locale),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(localized(data.service.description, locale)),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.price),
                Text(
                  rub(data.service.price, locale),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${t.duration}: ${t.serviceDuration(data.service.duration)}',
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/specialties/${data.service.specialtyId}'),
                  child: Text(localized(data.service.specialtyName, locale)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: t.bookAppointment,
            onPressed: () => context.push(
              Uri(
                path: '/booking',
                queryParameters: {'serviceId': id, 'doctorId': ?doctorId},
              ).toString(),
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localized(data.clinic.name, locale),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(localized(data.clinic.address, locale)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.doctorsOffering,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/doctors?serviceId=$id'),
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
                child: DoctorCard(doctor: d, serviceId: id),
              ),
            ),
        ],
      ),
    );
  }
}
