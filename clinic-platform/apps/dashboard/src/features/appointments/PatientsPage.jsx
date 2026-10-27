import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import { useDebounced } from "../../hooks/useDebounced";
import { Field } from "../../components/FormFields";
import {
  PageHeader,
  QueryState,
  DataTable,
  Pagination,
  Dialog,
  Submit,
  Failure,
  Status,
} from "../../components/Shared";
import { clinicDate } from "../../utils/time";
import AppointmentDetail from "./AppointmentDetail";
import MedicalRecords from "./MedicalRecords";
const schema = z
  .object({
    full_name: z.string().min(2).max(120),
    email: z.union([z.string().email(), z.literal("")]),
    phone: z.string().regex(/^\+[0-9]{8,15}$/),
    language: z.enum(["ru", "en"]),
    user_id: z.union([z.string().uuid(), z.literal("")]),
  })
  .refine((v) => Boolean(v.user_id || v.email), { path: ["email"] });
export function PatientForm({ onDone }) {
  const { t } = useLocale();
  const form = useForm({
      resolver: zodResolver(schema),
      defaultValues: {
        full_name: "",
        email: "",
        phone: "",
        language: "ru",
        user_id: "",
      },
    }),
    mutation = useAdminMutation("patients");
  return (
    <form
      className="stack-form"
      onSubmit={form.handleSubmit((v) =>
        mutation.mutate(
          {
            ...v,
            email: v.email || undefined,
            user_id: v.user_id || undefined,
          },
          { onSuccess: onDone },
        ),
      )}
    >
      <p className="muted">{t("patientInviteHelp")}</p>
      {["full_name", "email", "phone", "user_id"].map((name) => (
        <Field
          key={name}
          name={name}
          register={form.register}
          errors={form.formState.errors}
        />
      ))}
      <Field
        name="language"
        label="languages"
        register={form.register}
        errors={form.formState.errors}
        options={["ru", "en"].map((l) => [l, t(l)])}
      />
      {mutation.error && <Failure error={mutation.error} />}
      <Submit busy={mutation.isPending} />
    </form>
  );
}
export default function PatientsPage() {
  const { t } = useLocale();
  const [search, setSearch] = useState(""),
    [page, setPage] = useState(1),
    [selected, setSelected] = useState(null),
    [create, setCreate] = useState(false);
  const query = useAdminQuery("patients", {
    search: useDebounced(search),
    page,
    limit: 20,
  });
  return (
    <>
      <PageHeader
        title={t("patients")}
        actions={
          <button className="button" onClick={() => setCreate(true)}>
            {t("linkedPatient")}
          </button>
        }
      />
      <div className="filters">
        <input
          aria-label={t("patientSearch")}
          placeholder={t("patientSearch")}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
      </div>
      <section className="panel">
        <QueryState query={query}>
          {(data) => (
            <>
              <DataTable
                columns={[
                  { key: "full_name" },
                  { key: "phone" },
                  { key: "email" },
                  { key: "appointment_count" },
                  {
                    key: "actions",
                    render: (p) => (
                      <button
                        className="text-button"
                        onClick={() => setSelected(p.id)}
                      >
                        {t("view")}
                      </button>
                    ),
                  },
                ]}
                rows={data.items}
              />
              <Pagination value={data} onPage={setPage} />
            </>
          )}
        </QueryState>
      </section>
      {selected && (
        <Dialog title={t("patient")} onClose={() => setSelected(null)}>
          <PatientDetails id={selected} />
        </Dialog>
      )}
      {create && (
        <Dialog title={t("linkedPatient")} onClose={() => setCreate(false)}>
          <PatientForm onDone={() => setCreate(false)} />
        </Dialog>
      )}
    </>
  );
}
function PatientDetails({ id }) {
  const { t, locale, text } = useLocale(),
    { clinic } = useClinic();
  const [page, setPage] = useState(1),
    [appointment, setAppointment] = useState(null);
  const profile = useAdminQuery("patients/" + id),
    history = useAdminQuery("appointments", {
      patient_id: id,
      page,
      limit: 20,
    });
  return (
    <>
      <QueryState query={profile}>
        {(p) => (
          <dl className="details-grid">
            {["full_name", "phone", "email", "appointment_count"].map((k) => (
              <div key={k}>
                <dt>{t(k)}</dt>
                <dd>{p[k] ?? "—"}</dd>
              </div>
            ))}
          </dl>
        )}
      </QueryState>
      <h3>{t("patientHistory")}</h3>
      <QueryState query={history}>
        {(data) => (
          <>
            <DataTable
              rows={data.items}
              columns={[
                {
                  key: "starts_at",
                  render: (a) =>
                    clinicDate(a.starts_at, clinic.timezone, locale),
                },
                { key: "doctor_name", render: (a) => text(a.doctor_name) },
                { key: "status", render: (a) => <Status value={a.status} /> },
                {
                  key: "actions",
                  render: (a) => (
                    <button
                      className="text-button"
                      onClick={() => setAppointment(a.id)}
                    >
                      {t("view")}
                    </button>
                  ),
                },
              ]}
            />
            <Pagination value={data} onPage={setPage} />
          </>
        )}
      </QueryState>
      <MedicalRecords patientId={id} appointments={history.data?.items} />
      {appointment && (
        <AppointmentDetail
          id={appointment}
          onClose={() => setAppointment(null)}
        />
      )}
    </>
  );
}
