import 'package:flutter/material.dart';
import '../errors/app_exception.dart';
import '../localization/app_localizations.dart';
import '../utils/calendar_export.dart';

class AddToCalendarButton extends StatelessWidget {
  const AddToCalendarButton({
    super.key,
    required this.entry,
    this.calendar = const CalendarExport(),
  });
  final CalendarEntry entry;
  final CalendarExport calendar;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.event_available_outlined),
    label: Text(AppLocalizations.of(context)!.addToCalendar),
    onPressed: () async {
      try {
        await calendar.add(entry);
      } on AppException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.calendarUnavailable),
            ),
          );
        }
      }
    },
  );
}
