import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/widgets/scoped_list_view.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/appointment.dart';
import '../bloc/appointments_cubit.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({
    super.key,
    required this.clinicId,
    required this.timezone,
  });
  final String clinicId, timezone;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return ScopedListView<Appointment, AppointmentsCubit>(
      clinicId: clinicId,
      title: t.appointments,
      empty: t.noAppointments,
      footer: Text(t.bookingDetails),
      itemBuilder: (item) {
        final status = switch (item.status) {
          'pending' => t.pending,
          'confirmed' => t.confirmed,
          'completed' => t.completed,
          'cancelled' => t.cancelled,
          'no_show' => t.noShow,
          _ => t.unknownError,
        };
        final time = tz.TZDateTime.from(
          item.startsAt,
          tz.getLocation(timezone),
        );
        return AppCard(
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMMM y · HH:mm', locale).format(time),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(status),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
