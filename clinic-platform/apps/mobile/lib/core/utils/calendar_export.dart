import 'package:add_2_calendar/add_2_calendar.dart';
import '../errors/app_exception.dart';

class CalendarEntry {
  const CalendarEntry({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    this.description,
    this.location,
  });
  final String title, timezone;
  final String? description, location;
  final DateTime startsAt, endsAt;
}

// Opens the platform calendar editor prefilled with the appointment; the patient
// confirms the save there, so no calendar read access is requested.
class CalendarExport {
  const CalendarExport();
  Future<void> add(CalendarEntry entry) async {
    try {
      final opened = await Add2Calendar.addEvent2Cal(
        Event(
          title: entry.title,
          description: entry.description,
          location: entry.location,
          startDate: entry.startsAt.toLocal(),
          endDate: entry.endsAt.toLocal(),
          timeZone: entry.timezone,
          iosParams: const IOSParams(reminder: Duration(hours: 1)),
        ),
      );
      if (!opened) throw const AppException(FailureKind.unknown);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(FailureKind.unknown);
    }
  }
}
