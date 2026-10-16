import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/cancellation/request_cancellation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/repositories/patient_tools_repository.dart';
import '../bloc/appointments_cubit.dart';

class AppointmentActions extends StatefulWidget {
  const AppointmentActions({
    super.key,
    required this.appointment,
    required this.tools,
    required this.booking,
    required this.timezone,
  });
  final Appointment appointment;
  final PatientToolsRepository tools;
  final BookingRepository booking;
  final String timezone;
  @override
  State<AppointmentActions> createState() => _AppointmentActionsState();
}

class _AppointmentActionsState extends State<AppointmentActions> {
  bool busy = false;
  FailureKind? failure;
  Future<void> act(bool move) async {
    final a = widget.appointment;
    if (a.updatedAt == null) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final policy = await widget.tools.policy(a.clinicId);
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      if (move) {
        final changed = await showDialog<bool>(
          context: context,
          builder: (_) => RescheduleDialog(
            appointment: a,
            tools: widget.tools,
            booking: widget.booking,
            timezone: widget.timezone,
            minutes: policy.moveMinutes,
          ),
        );
        if (changed != true) return;
      } else {
        final approved = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.cancelAppointment),
            content: Text(t.noticeMinutes(policy.cancelMinutes)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.cancelAppointment),
              ),
            ],
          ),
        );
        if (approved != true || !mounted) return;
        await widget.tools.cancel(a.clinicId, a.id, a.updatedAt!);
      }
      if (mounted) {
        await context.read<AppointmentsCubit>().load(a.clinicId);
      }
    } on AppException catch (e) {
      if (mounted) setState(() => failure = e.kind);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => act(false),
              child: Text(t.cancelAppointment),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => act(true),
              child: Text(t.rescheduleAppointment),
            ),
          ],
        ),
        if (failure != null)
          Text(
            failureMessage(t, failure),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

class RescheduleDialog extends StatefulWidget {
  const RescheduleDialog({
    super.key,
    required this.appointment,
    required this.tools,
    required this.booking,
    required this.timezone,
    required this.minutes,
  });
  final Appointment appointment;
  final PatientToolsRepository tools;
  final BookingRepository booking;
  final String timezone;
  final int minutes;
  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  late DateTime day;
  List<AvailableSlot> slots = [];
  DateTime? selected;
  bool loading = true, busy = false;
  FailureKind? failure;
  RequestCancellation token = RequestCancellation();
  @override
  void initState() {
    super.initState();
    final now = tz.TZDateTime.now(tz.getLocation(widget.timezone));
    day = DateTime(now.year, now.month, now.day);
    load();
  }

  Future<void> load() async {
    token.cancel();
    token = RequestCancellation();
    setState(() {
      loading = true;
      failure = null;
      selected = null;
      slots = [];
    });
    try {
      final a = widget.appointment;
      final result = await widget.booking.availability(
        a.clinicId,
        a.doctorId!,
        a.serviceId!,
        DateFormat('yyyy-MM-dd').format(day),
        token,
      );
      if (mounted) setState(() => slots = result);
    } on AppException catch (e) {
      if (mounted && e.kind != FailureKind.cancelled) {
        setState(() => failure = e.kind);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode,
        zone = tz.getLocation(widget.timezone);
    return AlertDialog(
      title: Text(t.rescheduleAppointment),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.noticeMinutes(widget.minutes)),
              Text('${t.clinicTimezone}: ${widget.timezone}'),
              OutlinedButton(
                onPressed: busy || loading
                    ? null
                    : () async {
                        final now = tz.TZDateTime.now(zone),
                            today = DateTime(now.year, now.month, now.day);
                        final d = await showDatePicker(
                          context: context,
                          initialDate: day,
                          firstDate: today,
                          lastDate: today.add(const Duration(days: 180)),
                        );
                        if (d != null && mounted) {
                          setState(() => day = d);
                          await load();
                        }
                      },
                child: Text(DateFormat('d MMMM y', locale).format(day)),
              ),
              if (loading) const LinearProgressIndicator(),
              if (!loading && slots.isEmpty) Text(t.noAvailableTimes),
              Wrap(
                spacing: 8,
                children: slots
                    .map(
                      (s) => ChoiceChip(
                        label: Text(
                          DateFormat(
                            'HH:mm',
                          ).format(tz.TZDateTime.from(s.startsAt, zone)),
                        ),
                        selected: selected == s.startsAt,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => selected = s.startsAt),
                      ),
                    )
                    .toList(),
              ),
              if (failure != null) Text(failureMessage(t, failure)),
              if (failure != null && !busy)
                TextButton(onPressed: load, child: Text(t.retry)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: busy || loading || selected == null
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    failure = null;
                  });
                  try {
                    final a = widget.appointment;
                    await widget.tools.reschedule(
                      a.clinicId,
                      a.id,
                      a.updatedAt!,
                      selected!,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } on AppException catch (e) {
                    if (mounted) {
                      setState(() => failure = e.kind);
                      if (e.kind == FailureKind.bookingConflict) {
                        selected = null;
                      }
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(t.rescheduleAppointment),
        ),
      ],
    );
  }
}
