import { useState } from "react";
import { DateTime } from "luxon";
import { useDoctorMutation } from "../../hooks/useDoctor";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import { clinicNow, toInstant } from "../../utils/time";
import { Failure, Submit } from "../../components/Shared";
export default function ScheduleTools() {
  const { clinic } = useClinic(),
    { t } = useLocale();
  const [source, setSource] = useState(() =>
    clinicNow(clinic.timezone).startOf("week").toISODate(),
  );
  const [target, setTarget] = useState(() =>
    clinicNow(clinic.timezone).plus({ weeks: 1 }).startOf("week").toISODate(),
  );
  const [from, setFrom] = useState(""),
    [to, setTo] = useState(""),
    [day, setDay] = useState(""),
    [invalid, setInvalid] = useState(false);
  const copy = useDoctorMutation("schedule/copy"),
    block = useDoctorMutation("schedule/block");
  function saveBlock(starts_at, ends_at) {
    setInvalid(!starts_at || !ends_at || ends_at <= starts_at);
    if (
      starts_at &&
      ends_at &&
      ends_at > starts_at &&
      window.confirm(t("confirmAction"))
    )
      block.mutate({ starts_at, ends_at });
  }
  return (
    <section className="panel stack-form">
      <h2>{t("scheduleTools")}</h2>
      <p>{t("scheduleToolsHelp")}</p>
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (window.confirm(t("copyWeekConfirm")))
            copy.mutate({ source, target });
        }}
      >
        <label>
          {t("sourceWeek")}
          <input
            type="date"
            required
            value={source}
            onChange={(e) => setSource(e.target.value)}
          />
        </label>
        <label>
          {t("targetWeek")}
          <input
            type="date"
            required
            value={target}
            onChange={(e) => setTarget(e.target.value)}
          />
        </label>
        <Submit busy={copy.isPending}>{t("copyWeek")}</Submit>
      </form>
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          const d = DateTime.fromISO(day, { zone: clinic.timezone });
          saveBlock(
            d.startOf("day").toUTC().toISO(),
            d.plus({ days: 1 }).startOf("day").toUTC().toISO(),
          );
        }}
      >
        <label>
          {t("dayOff")}
          <input
            type="date"
            required
            value={day}
            min={clinicNow(clinic.timezone).plus({ days: 1 }).toISODate()}
            onChange={(e) => setDay(e.target.value)}
          />
        </label>
        <Submit busy={block.isPending}>{t("blockDay")}</Submit>
      </form>
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          saveBlock(
            toInstant(from, clinic.timezone),
            toInstant(to, clinic.timezone),
          );
        }}
      >
        <label>
          {t("vacationFrom")}
          <input
            type="datetime-local"
            required
            value={from}
            onChange={(e) => setFrom(e.target.value)}
          />
        </label>
        <label>
          {t("vacationTo")}
          <input
            type="datetime-local"
            required
            value={to}
            onChange={(e) => setTo(e.target.value)}
          />
        </label>
        <Submit busy={block.isPending}>{t("blockPeriod")}</Submit>
      </form>
      {invalid && <Failure error={{ code: "VALIDATION_ERROR" }} />}
      {copy.error && <Failure error={copy.error} />}
      {block.error && <Failure error={block.error} />}
    </section>
  );
}
