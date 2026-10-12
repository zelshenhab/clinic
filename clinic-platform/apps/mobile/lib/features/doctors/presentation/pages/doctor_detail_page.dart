import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/catalog_detail_page.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/catalog_image.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/doctor_detail.dart';
import '../bloc/doctor_detail_cubit.dart';
import '../../../services/presentation/widgets/service_card.dart';

class DoctorDetailPage extends StatelessWidget {
  const DoctorDetailPage({
    super.key,
    required this.clinicId,
    required this.id,
    this.serviceId,
  });
  final String clinicId, id;
  final String? serviceId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return CatalogDetailPage<DoctorDetail, DoctorDetailCubit>(
      clinicId: clinicId,
      title: t.viewProfile,
      load: (c, l) => c.get(clinicId, id, l),
      content: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CatalogImage(
              url: data.doctor.photoUrl,
              asset: 'assets/images/doctor.svg',
              label: t.demoAvatar,
              height: 220,
              width: 200,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            localized(data.doctor.name, locale),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(localized(data.doctor.title, locale)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.doctor.specialties
                .map(
                  (s) => ActionChip(
                    label: Text(localized(s.name, locale)),
                    onPressed: () => context.push('/specialties/${s.id}'),
                  ),
                )
                .toList(),
          ),
          if (data.doctor.experienceYears != null) ...[
            const SizedBox(height: 12),
            Text(t.yearsExperience(data.doctor.experienceYears!)),
          ],
          if (data.doctor.startingPrice != null) ...[
            const SizedBox(height: 8),
            Text(
              t.priceFrom(rub(data.doctor.startingPrice!, locale)),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.darkBlue,
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: t.bookAppointment,
            onPressed: () => context.push(
              Uri(
                path: '/booking',
                queryParameters: {'doctorId': id, 'serviceId': ?serviceId},
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
          ...[
                (t.biography, data.biography),
                (t.education, data.education),
                (t.qualifications, data.qualifications),
              ]
              .where((section) => localized(section.$2, locale).isNotEmpty)
              .map(
                (section) => Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.$1,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(localized(section.$2, locale)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 24),
          Text(
            t.spokenLanguages,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            data.languages
                .map(
                  (code) => switch (code) {
                    'ru' => t.russian,
                    'en' => t.english,
                    _ => code,
                  },
                )
                .join(' · '),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.doctorServices,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/services?doctorId=$id'),
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
                child: ServiceCard(service: s, doctorId: id),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t.scheduleOverview,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.schedules.isEmpty)
                  Text(t.noSchedule)
                else
                  ...data.schedules.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${scheduleDay(s.weekday, locale)} · ${s.start.substring(0, 5)}–${s.end.substring(0, 5)}',
                      ),
                    ),
                  ),
                const Divider(height: 24),
                Text(t.scheduleDisclaimer),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
