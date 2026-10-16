import HourlySchedule from "./HourlySchedule";
import RequestReview from "../doctor/RequestReview";
import { useDoctorMutation } from "../../hooks/useDoctor";
import { zodResolver } from "@hookform/resolvers/zod";
import { scheduleFormSchema } from "../../utils/formSchemas";
import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useForm, useFieldArray } from "react-hook-form";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import {
  QueryState,
  PageHeader,
  Submit,
  Failure,
} from "../../components/Shared";
import { Field } from "../../components/FormFields";
import { dateInput, toInstant } from "../../utils/time";
import AppointmentDetail from "../appointments/AppointmentDetail";
export default function SchedulesPage() {
  const { t, text } = useLocale(),
    { access } = useClinic();
  const [params, setParams] = useSearchParams(),
    doctor =
      params.get("doctor") ||
      (access.role === "DOCTOR" ? access.doctor_id : "") ||
      "",
    options = useAdminQuery("schedule-options"),
    schedule = useAdminQuery(
      "doctors/" + doctor + "/schedules",
      {},
      Boolean(doctor),
    );
  return (
    <>
      <PageHeader title={t("schedules")} subtitle={t("scheduleHelp")} />
      <QueryState query={options}>
        {(o) => (
          <label className="filters">
            {t("doctor")}
            <select
              aria-label={t("doctor")}
              value={doctor}
              onChange={(e) => setParams({ doctor: e.target.value })}
            >
              <option value="">{t("select")}</option>
              {o.doctors.map((d) => (
                <option key={d.id} value={d.id}>
                  {text(d.name)}
                </option>
              ))}
            </select>
          </label>
        )}
      </QueryState>
      {doctor && (
        <QueryState query={schedule}>
          {(data) => (
            <ScheduleEditor
              key={doctor + JSON.stringify(data)}
              doctor={doctor}
              data={data}
            />
          )}
        </QueryState>
      )}
      {["SUPER_ADMIN", "CLINIC_ADMIN"].includes(access.role) && (
        <RequestReview />
      )}
    </>
  );
}
function Breaks({ index, form }) {
  const { t } = useLocale(),
    fields = useFieldArray({
      control: form.control,
      name: `weekly.${index}.breaks`,
    });
  return (
    <fieldset>
      <legend>{t("breaks")}</legend>
      {form.formState.errors.weekly?.[index]?.breaks && (
        <small className="field-error">{t("fieldInvalid")}</small>
      )}
      {fields.fields.map((f, j) => (
        <div className="form-row" key={f.id}>
          <Field
            label="start"
            name={`weekly.${index}.breaks.${j}.start`}
            type="time"
            register={form.register}
            errors={form.formState.errors}
            required
          />
          <Field
            label="end"
            name={`weekly.${index}.breaks.${j}.end`}
            type="time"
            register={form.register}
            errors={form.formState.errors}
            required
          />
          <button
            type="button"
            className="text-button danger"
            onClick={() => fields.remove(j)}
          >
            {t("remove")}
          </button>
        </div>
      ))}
      <button
        type="button"
        className="text-button"
        onClick={() => fields.append({ start: "12:00", end: "13:00" })}
      >
        {t("addBreak")}
      </button>
    </fieldset>
  );
}
export function ScheduleEditor({
  doctor,
  data,
  requestMode = false,
  doctorDirect = false,
}) {
  const { t, locale } = useLocale(),
    { clinic, access } = useClinic(),
    editable =
      requestMode ||
      doctorDirect ||
      ["SUPER_ADMIN", "CLINIC_ADMIN"].includes(access.role),
    [reason, setReason] = useState(""),
    [conflict, setConflict] = useState(null);
  const form = useForm({
      resolver: zodResolver(scheduleFormSchema),
      defaultValues: {
        weekly: (data.weekly || []).map((s) => ({
          weekday: s.weekday,
          start: s.starts_at?.slice(0, 5) || s.start,
          end: s.ends_at?.slice(0, 5) || s.end,
          breaks: s.breaks || [],
        })),
        exceptions: (data.exceptions || []).map((e) => ({
          starts_at: dateInput(e.starts_at, clinic.timezone),
          ends_at: dateInput(e.ends_at, clinic.timezone),
          available: e.available,
        })),
      },
    }),
    weekly = useFieldArray({ control: form.control, name: "weekly" }),
    exceptions = useFieldArray({ control: form.control, name: "exceptions" }),
    adminMutation = useAdminMutation("doctors/" + doctor + "/schedules", "put"),
    requestMutation = useDoctorMutation("schedule-change-requests"),
    directMutation = useDoctorMutation("schedule", "put"),
    mutation = doctorDirect
      ? directMutation
      : requestMode
        ? requestMutation
        : adminMutation;
  const weekdays = Array.from({ length: 7 }, (_, i) => [
    i,
    new Intl.DateTimeFormat(locale, {
      weekday: "long",
      timeZone: "UTC",
    }).format(new Date(Date.UTC(2024, 0, 7 + i))),
  ]);
  return (
    <form
      className="stack-form panel"
      noValidate
      onSubmit={form.handleSubmit((v) => {
        const payload = {
          weekly: v.weekly.map((s) => ({
            weekday: s.weekday,
            starts_at: s.start,
            ends_at: s.end,
            breaks: s.breaks,
          })),
          exceptions: v.exceptions.map((e) => ({
            ...e,
            starts_at: toInstant(e.starts_at, clinic.timezone),
            ends_at: toInstant(e.ends_at, clinic.timezone),
          })),
        };
        if (requestMode) {
          if (reason.trim().length < 5) {
            form.setError("root", { message: "fieldInvalid" });
            return;
          }
          mutation.mutate({ kind: "schedule", payload, reason });
        } else mutation.mutate(doctorDirect ? { schedule: payload } : payload);
      })}
    >
      {requestMode && (
        <label>
          {t("requestReason")}
          <textarea
            aria-label={t("requestReason")}
            value={reason}
            maxLength={2000}
            onChange={(e) => setReason(e.target.value)}
          />
          {form.formState.errors.root && (
            <small className="field-error">{t("fieldInvalid")}</small>
          )}
          <small>{t("approvalRequired")}</small>
        </label>
      )}
      <p className="fine-print">
        {t("clinicTimezone")}: {clinic.timezone}. {t("bookingDurationHelp")}
      </p>
      <HourlySchedule form={form} disabled={!editable || mutation.isPending} />
      <fieldset disabled={!editable || mutation.isPending}>
        <legend>{t("weekly")}</legend>
        {weekly.fields.map((s, i) => (
          <div className="shift-card" key={s.id}>
            <div className="form-row">
              <label>
                {t("weekday")}
                <select
                  {...form.register(`weekly.${i}.weekday`, {
                    valueAsNumber: true,
                  })}
                >
                  {weekdays.map(([v, label]) => (
                    <option key={v} value={v}>
                      {label}
                    </option>
                  ))}
                </select>
              </label>
              <Field
                label="start"
                name={`weekly.${i}.start`}
                register={form.register}
                errors={form.formState.errors}
                type="time"
                required
              />
              <Field
                label="end"
                name={`weekly.${i}.end`}
                placeholder="HH:mm / 24:00"
                register={form.register}
                errors={form.formState.errors}
                type="text"
                required
              />
              {editable && (
                <button
                  type="button"
                  className="text-button danger"
                  onClick={() => weekly.remove(i)}
                >
                  {t("remove")}
                </button>
              )}
            </div>
            <Breaks index={i} form={form} />
          </div>
        ))}
        {editable && (
          <button
            type="button"
            className="button secondary"
            onClick={() =>
              weekly.append({
                weekday: 1,
                start: "00:00",
                end: "01:00",
                breaks: [],
              })
            }
          >
            {t("addShift")}
          </button>
        )}
      </fieldset>
      <fieldset disabled={!editable || mutation.isPending}>
        <legend>{t("exceptions")}</legend>
        {exceptions.fields.map((e, i) => (
          <div className="shift-card form-row" key={e.id}>
            <Field
              label="start"
              name={`exceptions.${i}.starts_at`}
              type="datetime-local"
              register={form.register}
              errors={form.formState.errors}
              required
            />
            <Field
              label="end"
              name={`exceptions.${i}.ends_at`}
              type="datetime-local"
              register={form.register}
              errors={form.formState.errors}
              required
            />
            <Field
              label="available"
              name={`exceptions.${i}.available`}
              type="checkbox"
              register={form.register}
              errors={form.formState.errors}
            />
            {editable && (
              <button
                type="button"
                className="text-button danger"
                onClick={() => exceptions.remove(i)}
              >
                {t("remove")}
              </button>
            )}
          </div>
        ))}
        {editable && (
          <button
            className="button secondary"
            type="button"
            onClick={() =>
              exceptions.append({
                starts_at: "",
                ends_at: "",
                available: false,
              })
            }
          >
            {t("addException")}
          </button>
        )}
      </fieldset>
      {mutation.error && (
        <>
          <Failure error={mutation.error} />
          {mutation.error.details?.appointmentIds?.map((id) => (
            <button
              className="text-button"
              type="button"
              key={id}
              onClick={() => setConflict(id)}
            >
              {t("view")}: {id}
            </button>
          ))}
        </>
      )}
      {editable && (
        <Submit busy={mutation.isPending}>
          {t(requestMode ? "submitRequest" : "save")}
        </Submit>
      )}{" "}
      {conflict && (
        <AppointmentDetail id={conflict} onClose={() => setConflict(null)} />
      )}
    </form>
  );
}
