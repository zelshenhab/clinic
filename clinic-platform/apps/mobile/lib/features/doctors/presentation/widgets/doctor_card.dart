import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/catalog_image.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/doctor.dart';

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, this.serviceId});
  final Doctor doctor;
  final String? serviceId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogImage(
                url: doctor.photoUrl,
                asset: 'assets/images/doctor.svg',
                label: t.demoAvatar,
                height: 100,
                width: 86,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localized(doctor.name, locale),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      doctor.specialties
                          .map((s) => localized(s.name, locale))
                          .join(' · '),
                    ),
                    if (doctor.experienceYears != null) ...[
                      const SizedBox(height: 6),
                      Text(t.yearsExperience(doctor.experienceYears!)),
                    ],
                    if (doctor.startingPrice != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        t.priceFrom(rub(doctor.startingPrice!, locale)),
                        style: const TextStyle(
                          color: AppColors.darkBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.push(
                  Uri(
                    path: '/doctors/${doctor.id}',
                    queryParameters: {'serviceId': ?serviceId},
                  ).toString(),
                ),
                child: Text(t.viewProfile),
              ),
              FilledButton(
                onPressed: () => context.push(
                  Uri(
                    path: '/booking',
                    queryParameters: {
                      'doctorId': doctor.id,
                      'serviceId': ?serviceId,
                    },
                  ).toString(),
                ),
                child: Text(t.bookAppointment),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
