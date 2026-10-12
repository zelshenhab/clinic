import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/medical_service.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, this.doctorId});
  final MedicalService service;
  final String? doctorId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(service.category, locale).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Text(
            localized(service.name, locale),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            localized(service.description, locale),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                rub(service.price, locale),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue,
                ),
              ),
              Text(t.serviceDuration(service.duration)),
              TextButton(
                onPressed: () => context.push(
                  Uri(
                    path: '/services/${service.id}',
                    queryParameters: {'doctorId': ?doctorId},
                  ).toString(),
                ),
                child: Text(t.moreDetails),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
