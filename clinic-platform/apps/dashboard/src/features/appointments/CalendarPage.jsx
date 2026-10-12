import { calendarLanes } from "../../utils/calendarLayout";
import { useState } from "react";
import { DateTime } from "luxon";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useAdminQuery } from "../../hooks/useAdmin";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import { clinicNow, clinicDate, rangeFor } from "../../utils/time";
import {
  PageHeader,
  QueryState,
  Status,
  Failure,
} from "../../components/Shared";
import AppointmentDetail from "./AppointmentDetail";
export default function CalendarPage() {
  const { clinic } = useClinic(),
    { t, text, locale } = useLocale();
  const [view, setView] = useState("week"),
    [day, setDay] = useState(() => clinicNow(clinic.timezone).toISODate()),
    [doctor, setDoctor] = useState(""),
    [detail, setDetail] = useState(null);
  const range = rangeFor(day, view, clinic.timezone);
  const query = useAdminQuery("calendar", {
      from: range.from,
      to: range.to,
      ...(doctor ? { doctor_id: doctor } : {}),
    }),
    options = useAdminQuery("filter-options");
  const days = [];
  for (let d = range.start; d <= range.end; d = d.plus({ days: 1 }))
    days.push(d);
  function move(direction) {
    setDay(
      DateTime.fromISO(day, { zone: clinic.timezone })
        .plus({
          [view === "month" ? "months" : view === "week" ? "weeks" : "days"]:
            direction,
        })
        .toISODate(),
    );
  }
  return (
    <>
      <PageHeader
        title={t("calendar")}
        subtitle={t("clinicTimezone") + ": " + clinic.timezone}
      />
      <div className="calendar-toolbar">
        <div className="action-row">
          <button
            className="icon-button"
            aria-label={t("previous")}
            onClick={() => move(-1)}
          >
            <ChevronLeft />
          </button>
          <button
            className="button secondary"
            onClick={() => setDay(clinicNow(clinic.timezone).toISODate())}
          >
            {t("today")}
          </button>
          <button
            className="icon-button"
            aria-label={t("next")}
            onClick={() => move(1)}
          >
            <ChevronRight />
          </button>
          <strong>
            {DateTime.fromISO(day)
              .setLocale(locale)
              .toLocaleString({ month: "long", year: "numeric" })}
          </strong>
        </div>
        <div className="action-row">
          <select
            aria-label={t("doctor")}
            value={doctor}
            onChange={(e) => setDoctor(e.target.value)}
          >
            <option value="">{t("allDoctors")}</option>
            {options.data?.doctors.map((d) => (
              <option value={d.id} key={d.id}>
                {text(d.name)}
              </option>
            ))}
          </select>
          <div className="segmented">
            {["day", "week", "month"].map((v) => (
              <button
                key={v}
                className={view === v ? "selected" : ""}
                onClick={() => setView(v)}
              >
                {t(v)}
              </button>
            ))}
          </div>
        </div>
      </div>
      {options.error && (
        <Failure error={options.error} retry={options.refetch} />
      )}
      <QueryState query={query}>
        {(data) => (
          <>
            {data.truncated && (
              <div className="notice">{t("calendarLimit")}</div>
            )}
            <div
              className={`calendar-board ${view}`}
              style={{
                "--columns":
                  view === "day"
                    ? Math.max(
                        1,
                        (options.data?.doctors || []).filter(
                          (d) => !doctor || d.id === doctor,
                        ).length,
                      )
                    : 7,
              }}
            >
              {view === "month"
                ? days.map((d) => (
                    <section
                      className={`calendar-cell ${d.month !== DateTime.fromISO(day).month ? "outside" : ""}`}
                      key={d.toISODate()}
                    >
                      <strong>{d.toFormat("d")}</strong>
                      {data.items
                        .filter(
                          (a) =>
                            DateTime.fromISO(a.starts_at)
                              .setZone(clinic.timezone)
                              .toISODate() === d.toISODate(),
                        )
                        .map((a) => (
                          <Event
                            key={a.id}
                            record={a}
                            onClick={() => setDetail(a.id)}
                          />
                        ))}
                    </section>
                  ))
                : view === "week"
                  ? days.map((d) => (
                      <section className="calendar-day" key={d.toISODate()}>
                        <h3>{d.setLocale(locale).toFormat("ccc d")}</h3>
                        <Timeline
                          date={d}
                          items={data.items.filter(
                            (a) =>
                              DateTime.fromISO(a.starts_at)
                                .setZone(clinic.timezone)
                                .toISODate() === d.toISODate(),
                          )}
                          onSelect={setDetail}
                        />
                      </section>
                    ))
                  : (options.data?.doctors || [])
                      .filter((d) => !doctor || d.id === doctor)
                      .map((d) => (
                        <section className="calendar-day" key={d.id}>
                          <h3>{text(d.name)}</h3>
                          <Timeline
                            date={range.start}
                            items={data.items.filter(
                              (a) => a.doctor_id === d.id,
                            )}
                            onSelect={setDetail}
                          />
                        </section>
                      ))}
            </div>
          </>
        )}
      </QueryState>
      {detail && (
        <AppointmentDetail id={detail} onClose={() => setDetail(null)} />
      )}
    </>
  );
}
function Event({ record, onClick, style }) {
  const { clinic } = useClinic(),
    { text, locale } = useLocale();
  return (
    <button
      className={`calendar-event ${record.status}`}
      title={clinicDate(record.starts_at, clinic.timezone, locale)}
      style={style}
      onClick={onClick}
    >
      <time>
        {DateTime.fromISO(record.starts_at)
          .setZone(clinic.timezone)
          .toFormat("HH:mm")}
      </time>
      <strong>{record.patient_name}</strong>
      <span>{text(record.doctor_name)}</span>
      <small>{text(record.service_name)}</small>
    </button>
  );
}
function Timeline({ date, items, onSelect }) {
  const minutes = date.plus({ days: 1 }).diff(date, "minutes").minutes;
  return (
    <div className="calendar-timeline" style={{ height: minutes * 0.8 }}>
      {Array.from({ length: Math.ceil(minutes / 60) }, (_, hour) => (
        <div className="hour-line" key={hour} style={{ top: hour * 48 }}>
          <span>{date.plus({ hours: hour }).toFormat("HH:mm")}</span>
        </div>
      ))}
      {calendarLanes(items).map(({ record: a, left, width }) => {
        const start = DateTime.fromISO(a.starts_at),
          end = DateTime.fromISO(a.ends_at);
        return (
          <Event
            key={a.id}
            record={a}
            onClick={() => onSelect(a.id)}
            style={{
              position: "absolute",
              left: `${left}%`,
              width: `calc(${width}% - 3px)`,
              top: start.diff(date, "minutes").minutes * 0.8,
              height: Math.max(2, end.diff(start, "minutes").minutes * 0.8),
            }}
          />
        );
      })}
    </div>
  );
}
