import { useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, adminPath } from "../../services/api";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import { useToast } from "../../contexts/ToastContext";
import {
  QueryState,
  DataTable,
  Failure,
  Submit,
} from "../../components/Shared";
import { clinicDate } from "../../utils/time";

export const RECORD_KINDS = [
  "report",
  "lab_result",
  "imaging",
  "prescription",
  "other",
];

// Doctors use their own workspace routes; administrators and reception use the clinic routes.
function endpoints(clinic, access) {
  const doctor = access?.role === "DOCTOR",
    params = doctor ? { clinic_id: clinic.id } : undefined,
    path = (p) => (doctor ? "/doctor/" + p : adminPath(clinic.id, p));
  return {
    list: (patient, signal) =>
      api.get(path(`patients/${patient}/medical-records`), { params, signal }),
    upload: (patient, form) =>
      api.post(path(`patients/${patient}/medical-records`), form, { params }),
    download: (id) =>
      api.get(path(`medical-records/${id}/download`), { params }),
    remove: (id) => api.delete(path(`medical-records/${id}`), { params }),
  };
}

export default function MedicalRecords({ patientId, appointments = [] }) {
  const { clinic, access } = useClinic(),
    { t, text, locale } = useLocale(),
    toast = useToast(),
    client = useQueryClient(),
    routes = endpoints(clinic, access),
    key = ["clinic", clinic.id, "medical-records", patientId, access?.role],
    fileRef = useRef(),
    [form, setForm] = useState({
      title: "",
      kind: "lab_result",
      appointment_id: "",
    });
  const query = useQuery({
    queryKey: key,
    queryFn: ({ signal }) => routes.list(patientId, signal),
  });
  const refresh = () =>
    client.invalidateQueries({
      queryKey: ["clinic", clinic.id, "medical-records"],
    });
  const upload = useMutation({
    mutationFn: () => {
      const data = new FormData();
      data.append("title", form.title.trim());
      data.append("kind", form.kind);
      if (form.appointment_id)
        data.append("appointment_id", form.appointment_id);
      data.append("file", fileRef.current.files[0]);
      return routes.upload(patientId, data);
    },
    retry: false,
    onSuccess: () => {
      setForm((f) => ({ ...f, title: "", appointment_id: "" }));
      fileRef.current.value = "";
      refresh();
      toast(t("recordUploaded"));
    },
  });
  const remove = useMutation({
    mutationFn: (id) => routes.remove(id),
    retry: false,
    onSuccess: () => {
      refresh();
      toast(t("saved"));
    },
    onError: (error) => toast(t(error.code) || t("unexpected"), "error"),
  });
  const open = async (id) => {
    try {
      const link = await routes.download(id);
      window.open(link.url, "_blank", "noopener");
    } catch (error) {
      toast(t(error.code) || t("unexpected"), "error");
    }
  };
  return (
    <section className="medical-records">
      <h3>{t("medicalRecords")}</h3>
      <form
        className="stack-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (!fileRef.current?.files?.length || !form.title.trim())
            return toast(t("DOCUMENT_INVALID"), "error");
          upload.mutate();
        }}
      >
        <label>
          {t("recordTitle")}
          <input
            required
            maxLength={200}
            value={form.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
          />
        </label>
        <label>
          {t("recordKind")}
          <select
            value={form.kind}
            onChange={(e) => setForm({ ...form, kind: e.target.value })}
          >
            {RECORD_KINDS.map((k) => (
              <option key={k} value={k}>
                {t("record_" + k)}
              </option>
            ))}
          </select>
        </label>
        <label>
          {t("recordAppointment")}
          <select
            value={form.appointment_id}
            onChange={(e) =>
              setForm({ ...form, appointment_id: e.target.value })
            }
          >
            <option value="">{t("recordNoAppointment")}</option>
            {appointments.map((a) => (
              <option key={a.id} value={a.id}>
                {clinicDate(a.starts_at, clinic.timezone, locale)} ·{" "}
                {text(a.doctor_name || a.service_name)}
                {a.family_member_id ? " · " + a.patient_name : ""}
              </option>
            ))}
          </select>
        </label>
        <label>
          {t("recordFile")}
          <input
            ref={fileRef}
            type="file"
            accept="application/pdf,image/jpeg,image/png"
          />
        </label>
        {upload.error && <Failure error={upload.error} />}
        <Submit busy={upload.isPending}>{t("uploadRecord")}</Submit>
      </form>
      <QueryState query={query}>
        {(rows) => (
          <DataTable
            rows={rows}
            columns={[
              {
                key: "created_at",
                render: (r) =>
                  clinicDate(r.created_at, clinic.timezone, locale),
              },
              { key: "recordTitle", render: (r) => r.title },
              { key: "recordKind", render: (r) => t("record_" + r.kind) },
              {
                key: "patient_name",
                render: (r) => r.family_member_name || t("recordAccountHolder"),
              },
              { key: "doctor_name", render: (r) => text(r.doctor_name) || "—" },
              {
                key: "actions",
                render: (r) => (
                  <>
                    <button className="text-button" onClick={() => open(r.id)}>
                      {t("download")}
                    </button>{" "}
                    <button
                      className="text-button"
                      disabled={remove.isPending}
                      onClick={() =>
                        window.confirm(t("recordRemoveConfirm")) &&
                        remove.mutate(r.id)
                      }
                    >
                      {t("remove")}
                    </button>
                  </>
                ),
              },
            ]}
          />
        )}
      </QueryState>
    </section>
  );
}
