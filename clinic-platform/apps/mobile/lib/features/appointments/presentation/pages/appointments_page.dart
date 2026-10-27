import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../domain/repositories/patient_tools_repository.dart';
import '../../domain/repositories/booking_repository.dart';
import 'appointment_actions.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/widgets/scoped_list_view.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/appointment.dart';
import '../bloc/appointments_cubit.dart';
import '../../../clinic_selection/domain/entities/clinic.dart';
import '../../../../core/utils/calendar_export.dart';
import '../../../../core/widgets/add_to_calendar_button.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({
    super.key,
    required this.clinicId,
    required this.timezone,
    this.tools,
    this.booking,
    this.clinic,
  });
  final String clinicId, timezone;
  final Clinic? clinic;
  final PatientToolsRepository? tools;
  final BookingRepository? booking;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return ScopedListView<Appointment, AppointmentsCubit>(
      clinicId: clinicId,
      title: t.appointments,
      empty: t.noAppointments,
      footer: Column(
        children: [
          Text(t.bookingDetails),
          TextButton(
            onPressed: () => context.push("/waitlist"),
            child: Text(t.waitlist),
          ),
        ],
      ),
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
                    if (item.familyMemberId != null &&
                        (item.patientName ?? '').isNotEmpty)
                      Text(t.appointmentFor(item.patientName!)),
                    if (item.doctorName.isNotEmpty)
                      Text(localized(item.doctorName, locale)),
                    if (item.serviceName.isNotEmpty)
                      Text(localized(item.serviceName, locale)),
                    if (item.attendanceStatus != "scheduled")
                      Text(switch (item.attendanceStatus) {
                        "arrived" => t.arrived,
                        "waiting" => t.waiting,
                        "in_consultation" => t.inConsultation,
                        "finished" => t.completed,
                        _ => "",
                      }),
                    if (tools != null &&
                        booking != null &&
                        item.updatedAt != null &&
                        item.doctorId != null &&
                        item.serviceId != null &&
                        item.startsAt.isAfter(DateTime.now()) &&
                        ["pending", "confirmed"].contains(item.status) &&
                        item.attendanceStatus == "scheduled")
                      AppointmentActions(
                        appointment: item,
                        tools: tools!,
                        booking: booking!,
                        timezone: timezone,
                      ),
                    if (item.startsAt.isAfter(DateTime.now()) &&
                        ["pending", "confirmed"].contains(item.status))
                      AddToCalendarButton(
                        entry: CalendarEntry(
                          title: t.calendarEventTitle(
                            localized(item.doctorName, locale),
                          ),
                          description: [
                            localized(item.serviceName, locale),
                            if (item.familyMemberId != null) ?item.patientName,
                          ].where((v) => v.isNotEmpty).join('\n'),
                          location: clinic == null
                              ? null
                              : [
                                  localized(clinic!.name, locale),
                                  localized(clinic!.address, locale),
                                ].where((v) => v.isNotEmpty).join(', '),
                          startsAt: item.startsAt,
                          endsAt:
                              item.endsAt ??
                              item.startsAt.add(const Duration(minutes: 30)),
                          timezone: timezone,
                        ),
                      ),
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
