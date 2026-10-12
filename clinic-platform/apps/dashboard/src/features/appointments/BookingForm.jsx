import { PatientForm } from "./PatientsPage";
import { Dialog } from "../../components/Shared";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import { useDebounced } from "../../hooks/useDebounced";
import { clinicNow, clinicDate } from "../../utils/time";
import { QueryState, Failure, Submit, Empty } from "../../components/Shared";
export default function BookingForm({ existing, onDone }) {
  const { clinic } = useClinic(),
    { t, text, locale } = useLocale();
  const [creating, setCreating] = useState(false);
  const [search, setSearch] = useState(""),
    debounced = useDebounced(search);
  const {
    register,
    watch,
    setValue,
    handleSubmit,
    formState: { errors },
  } = useForm({
    defaultValues: {
      patient_id: existing?.patient_id || "",
      doctor_id: existing?.doctor_id || "",
      service_id: existing?.service_id || "",
      date: clinicNow(clinic.timezone).plus({ days: 1 }).toISODate(),
      starts_at: "",
    },
  });
  const values = watch(),
    options = useAdminQuery("options"),
    patients = useAdminQuery(
      "patients",
      { search: debounced, limit: 20 },
      !existing,
    );
  const slots = useAdminQuery(
    "availability",
    {
      doctor_id: values.doctor_id,
      service_id: values.service_id,
      date: values.date,
    },
    Boolean(values.doctor_id && values.service_id && values.date),
  );
  const mutation = useAdminMutation(
    existing ? "appointments/" + existing.id : "appointments",
    existing ? "patch" : "post",
  );
  const clearSlot = () => setValue("starts_at", "");
  return (
    <>
      <form
        className="stack-form"
        onSubmit={handleSubmit((input) =>
          mutation.mutate(
            existing
              ? {
                  starts_at: input.starts_at,
                  expected_updated_at: existing.updated_at,
                }
              : {
                  patient_id: input.patient_id,
                  doctor_id: input.doctor_id,
                  service_id: input.service_id,
                  starts_at: input.starts_at,
                },
            { onSuccess: onDone },
          ),
        )}
      >
        <p className="muted">
          {t("bookingHelp")} {clinic.timezone}
        </p>
        {!existing && (
          <>
            <button
              type="button"
              className="text-button"
              onClick={() => setCreating(true)}
            >
              {t("linkedPatient")}
            </button>
            <label>
              {t("patientSearch")}
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </label>
            <QueryState query={patients}>
              {(data) => (
                <label>
                  {t("patient")}
                  <select
                    aria-label={t("patient")}
                    {...register("patient_id", { required: true })}
                  >
                    <option value="">{t("select")}</option>
                    {data.items.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.full_name} · {p.phone}
                      </option>
                    ))}
                  </select>
                  {errors.patient_id && (
                    <small className="field-error">{t("required")}</small>
                  )}
                </label>
              )}
            </QueryState>
          </>
        )}
        <QueryState query={options}>
          {(data) => (
            <div className="form-grid">
              <label>
                {t("doctor")}
                <select
                  disabled={Boolean(existing)}
                  aria-label={t("doctor")}
                  {...register("doctor_id", {
                    required: !existing,
                    onChange: () => {
                      setValue("service_id", "");
                      clearSlot();
                    },
                  })}
                >
                  <option value="">{t("select")}</option>
                  {data.doctors.map((d) => (
                    <option key={d.id} value={d.id}>
                      {text(d.name)}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                {t("service")}
                <select
                  aria-label={t("service")}
                  disabled={Boolean(existing)}
                  {...register("service_id", {
                    required: !existing,
                    onChange: clearSlot,
                  })}
                >
                  <option value="">{t("select")}</option>
                  {data.services
                    .filter((s) => s.doctor_ids.includes(values.doctor_id))
                    .map((s) => (
                      <option key={s.id} value={s.id}>
                        {text(s.name)} · {s.price_rub} ₽
                      </option>
                    ))}
                </select>
              </label>
              <label>
                {t("date")}
                <input
                  type="date"
                  min={clinicNow(clinic.timezone).toISODate()}
                  {...register("date", { required: true, onChange: clearSlot })}
                />
              </label>
            </div>
          )}
        </QueryState>
        {values.doctor_id && values.service_id && values.date && (
          <QueryState query={slots}>
            {(data) =>
              data.length ? (
                <label>
                  {t("slots")}
                  <select
                    disabled={slots.isFetching}
                    aria-label={t("slots")}
                    {...register("starts_at", { required: true })}
                  >
                    <option value="">{t("select")}</option>
                    {data.map((s) => (
                      <option key={s.starts_at} value={s.starts_at}>
                        {clinicDate(s.starts_at, clinic.timezone, locale)}
                      </option>
                    ))}
                  </select>
                  {errors.starts_at && (
                    <small className="field-error">{t("required")}</small>
                  )}
                </label>
              ) : (
                <Empty label={t("noSlots")} />
              )
            }
          </QueryState>
        )}
        {mutation.error && (
          <Failure error={mutation.error} retry={slots.refetch} />
        )}
        <Submit
          busy={mutation.isPending}
          disabled={!values.starts_at || slots.isFetching}
        >
          {t(existing ? "reschedule" : "book")}
        </Submit>
      </form>
      {creating && (
        <Dialog title={t("linkedPatient")} onClose={() => setCreating(false)}>
          <PatientForm
            onDone={() => {
              setCreating(false);
              patients.refetch();
            }}
          />
        </Dialog>
      )}
    </>
  );
}
