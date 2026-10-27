import 'booking_slots.dart';
import '../../domain/repositories/patient_tools_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/catalog/catalog_query.dart';
import '../../../../core/widgets/catalog_detail_page.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/contact_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../domain/entities/booking_context.dart';
import '../bloc/booking_entry_cubit.dart';
import '../../../family/domain/repositories/family_repository.dart';

class BookingEntryPage extends StatelessWidget {
  const BookingEntryPage({
    super.key,
    required this.clinicId,
    this.query = const CatalogQuery(),
    this.tools,
    this.family,
    this.initialDate,
  });
  final FamilyRepository? family;
  final String clinicId;
  final CatalogQuery query;
  final PatientToolsRepository? tools;
  final String? initialDate;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return CatalogDetailPage<BookingContext, BookingEntryCubit>(
      clinicId: clinicId,
      title: t.bookingEntryTitle,
      load: (c, l) => c.get(clinicId, query.copy(locale: l)),
      content: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.bookingEntryTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(t.bookingEntryBody),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.selectedClinic,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  localized(data.clinic.name, locale),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(localized(data.clinic.address, locale)),
                if (data.specialty != null) ...[
                  const Divider(height: 24),
                  Text(localized(data.specialty!.name, locale)),
                ],
                if (data.doctor != null) ...[
                  const Divider(height: 24),
                  Text(localized(data.doctor!.name, locale)),
                ],
                if (data.service != null) ...[
                  const Divider(height: 24),
                  Text(localized(data.service!.name, locale)),
                  Text(rub(data.service!.price, locale)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (data.doctor != null && data.service != null)
            BookingSlots(
              key: ValueKey(
                '${data.clinic.id}:${data.doctor!.id}:${data.service!.id}',
              ),
              data: data,
              query: query,
              tools: tools,
              family: family,
              initialDate: initialDate,
            ),
          const SizedBox(height: 24),
          AppButton(
            label: t.selectDoctor,
            onPressed: () => context.go(
              CatalogQuery(
                specialtyId: query.specialtyId,
                serviceId: query.serviceId,
              ).path('/doctors'),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: t.selectService,
            onPressed: () => context.push(
              CatalogQuery(
                specialtyId: query.specialtyId,
                doctorId: query.doctorId,
              ).path('/services'),
            ),
          ),
          if (data.clinic.phone != null) ...[
            const SizedBox(height: 24),
            ContactButton(phone: data.clinic.phone!),
          ],
        ],
      ),
    );
  }
}
