import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/clinic.dart';

class ClinicImage extends StatelessWidget {
  const ClinicImage({super.key, this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final fallback = SvgPicture.asset(
      'assets/images/clinic.svg',
      fit: BoxFit.cover,
      semanticsLabel: AppLocalizations.of(context)!.clinicIllustration,
    );
    return SizedBox(
      height: 165,
      width: double.infinity,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class ClinicCard extends StatelessWidget {
  const ClinicCard({super.key, required this.clinic, required this.select});
  final Clinic clinic;
  final VoidCallback select;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: ClinicImage(url: clinic.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.demoContent.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  clinic.text(clinic.name, locale),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(clinic.text(clinic.address, locale))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(clinic.text(clinic.description, locale)),
                const SizedBox(height: 20),
                AppButton(
                  label: t.clinicSelect,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: select,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
