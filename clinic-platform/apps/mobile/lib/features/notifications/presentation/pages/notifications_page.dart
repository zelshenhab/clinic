import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../appointments/domain/repositories/patient_tools_repository.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/widgets/scoped_list_view.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../domain/entities/clinic_notification.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.clinicId, this.tools});
  final String clinicId;
  final PatientToolsRepository? tools;
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
              if (tools != null)
                NotificationActions(
                  key: ValueKey(n.id),
                  notice: n,
                  clinic: clinicId,
                  tools: tools!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationActions extends StatefulWidget {
  const NotificationActions({
    super.key,
    required this.notice,
    required this.clinic,
    required this.tools,
  });
  final ClinicNotification notice;
  final String clinic;
  final PatientToolsRepository tools;
  @override
  State<NotificationActions> createState() => _NotificationActionsState();
}

class _NotificationActionsState extends State<NotificationActions> {
  bool busy = false;
  FailureKind? failure;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!, n = widget.notice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            TextButton(
              onPressed: () => context.push(
                n.kind == 'waitlist' ? '/waitlist' : '/appointments',
              ),
              child: Text(n.kind == 'waitlist' ? t.waitlist : t.appointments),
            ),
            if (n.readAt == null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await widget.tools.readNotification(
                            widget.clinic,
                            n.id,
                          );
                          if (context.mounted) {
                            await context.read<NotificationsCubit>().load(
                              widget.clinic,
                            );
                          }
                        } on AppException catch (e) {
                          if (mounted) setState(() => failure = e.kind);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(t.markRead),
              )
            else
              Text(t.readNotification),
          ],
        ),
        if (failure != null) Text(failureMessage(t, failure)),
      ],
    );
  }
}
