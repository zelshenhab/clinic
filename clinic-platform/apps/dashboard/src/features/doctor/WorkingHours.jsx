import { DateTime } from "luxon";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import { clinicDate } from "../../utils/time";
export default function WorkingHours({ data }) {
  const { t, locale } = useLocale(),
    { clinic } = useClinic();
  return (
    <section className="panel">
      <h3>{t("currentSchedule")}</h3>
      <p className="fine-print">
        {t("clinicTimezone")}: {clinic.timezone}
      </p>
      <div className="doctor-hours">
        {Array.from({ length: 7 }, (_, day) => {
          const shifts = data?.weekly?.filter((s) => s.weekday === day) || [];
          return (
            <div className="shift-card" key={day}>
              <strong>
                {DateTime.fromISO("2024-01-07")
                  .plus({ days: day })
                  .setLocale(locale)
                  .toFormat("cccc")}
              </strong>
              {shifts.length ? (
                shifts.map((s, i) => (
                  <p key={i}>
                    {s.starts_at.slice(0, 5)}–{s.ends_at.slice(0, 5)}
                    <small>
                      {t("breaks")}:{" "}
                      {s.breaks?.map((b) => b.start + "–" + b.end).join(", ") ||
                        "—"}
                    </small>
                  </p>
                ))
              ) : (
                <p>{t("dayOff")}</p>
              )}
            </div>
          );
        })}
      </div>
      {!!data?.exceptions?.length && (
        <>
          <h4>{t("exceptions")}</h4>
          {data.exceptions.map((e, i) => (
            <p key={e.id || i}>
              {clinicDate(e.starts_at, clinic.timezone, locale)} →{" "}
              {clinicDate(e.ends_at, clinic.timezone, locale)} ·{" "}
              {t(e.available ? "available" : "dayOff")}
            </p>
          ))}
        </>
      )}
    </section>
  );
}
