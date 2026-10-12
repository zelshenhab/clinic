import 'package:flutter/material.dart';
import '../../../../core/widgets/scoped_list_view.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../domain/entities/clinic_notification.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.clinicId});
  final String clinicId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return AppScaffold(
      title: t.notifications,
      child: ScopedListView<ClinicNotification, NotificationsCubit>(
        clinicId: clinicId,
        title: t.notifications,
        empty: t.noNotifications,
        itemBuilder: (n) => AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localized(n.title, locale),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(localized(n.body, locale)),
            ],
          ),
        ),
      ),
    );
  }
}
