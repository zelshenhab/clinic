import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/specialty.dart';

IconData specialtyIcon(String name) => switch (name) {
  'heart' => Icons.favorite_outline,
  'brain' => Icons.psychology_outlined,
  'eye' => Icons.visibility_outlined,
  'family' => Icons.family_restroom,
  'tooth' => Icons.sentiment_satisfied_alt_outlined,
  'bone' => Icons.accessibility_new,
  'scan' => Icons.monitor_heart_outlined,
  'skin' => Icons.spa_outlined,
  _ => Icons.health_and_safety_outlined,
};

class SpecialtyCard extends StatelessWidget {
  const SpecialtyCard({super.key, required this.specialty});
  final Specialty specialty;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/specialties/${specialty.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(specialtyIcon(specialty.icon), color: AppColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localized(specialty.name, locale),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localized(specialty.description, locale),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.specialtyDoctorCount(specialty.doctorCount),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}
