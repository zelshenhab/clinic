import { useLocale } from "../../contexts/LocaleContext";
import {
  hourEnabled,
  toggleHour,
  dayIntervals,
} from "../../utils/hourlySchedule";
export default function HourlySchedule({ form, disabled }) {
  const { t, locale } = useLocale(),
    weekly = form.watch("weekly") || [];
  const weekdays = Array.from({ length: 7 }, (_, i) =>
    new Intl.DateTimeFormat(locale, {
      weekday: "short",
      timeZone: "UTC",
    }).format(new Date(Date.UTC(2024, 0, 7 + i))),
  );
  return (
    <section className="hourly-editor">
      <h3>{t("hourlyAvailability")}</h3>
      <p>{t("hourlyHelp")}</p>
      <div className="table-scroll">
        <table className="hourly-grid">
          <thead>
            <tr>
              <th>{t("appointmentTime")}</th>
              {weekdays.map((day, i) => (
                <th key={i}>{day}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {Array.from({ length: 24 }, (_, hour) => (
              <tr key={hour}>
                <th>
                  {String(hour).padStart(2, "0")}:00–
                  {String(hour + 1).padStart(2, "0")}:00
                </th>
                {weekdays.map((day, index) => {
                  const on = hourEnabled(weekly, index, hour),
                    partial =
                      !on &&
                      dayIntervals(weekly, index).some(
                        ([a, b]) => a < (hour + 1) * 60 && b > hour * 60,
                      );
                  return (
                    <td key={index}>
                      <button
                        type="button"
                        className={
                          on
                            ? "hour-open"
                            : partial
                              ? "hour-partial"
                              : "hour-closed"
                        }
                        disabled={disabled}
                        aria-pressed={partial ? "mixed" : on}
                        aria-label={`${day} ${String(hour).padStart(2, "0")}:00`}
                        onClick={() =>
                          form.setValue(
                            "weekly",
                            toggleHour(weekly, index, hour),
                            { shouldDirty: true, shouldValidate: true },
                          )
                        }
                      >
                        {t(
                          on
                            ? "available"
                            : partial
                              ? "partlyAvailable"
                              : "unavailable",
                        )}
                      </button>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
