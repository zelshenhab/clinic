import { DateTime } from "luxon";
export const clinicNow = (zone) => DateTime.now().setZone(zone);
export const clinicDate = (iso, zone, locale = "ru") =>
  DateTime.fromISO(iso)
    .setZone(zone)
    .setLocale(locale)
    .toLocaleString(DateTime.DATETIME_MED);
export const dateInput = (iso, zone) =>
  DateTime.fromISO(iso).setZone(zone).toFormat("yyyy-MM-dd'T'HH:mm");
export function toInstant(local, zone) {
  const date = DateTime.fromISO(local, { zone });
  if (
    !date.isValid ||
    date.toFormat("yyyy-MM-dd'T'HH:mm") !== local.slice(0, 16) ||
    date.getPossibleOffsets().length > 1
  )
    return null;
  return date.toUTC().toISO();
}
export function rangeFor(day, view, zone) {
  const date = DateTime.fromISO(day, { zone });
  const start =
    view === "month"
      ? date.startOf("month").startOf("week")
      : date.startOf(view === "week" ? "week" : "day");
  const end =
    view === "month"
      ? date.endOf("month").endOf("week")
      : date.endOf(view === "week" ? "week" : "day");
  return {
    from: start.toUTC().toISO(),
    to: end.plus({ milliseconds: 1 }).toUTC().toISO(),
    start,
    end,
  };
}
