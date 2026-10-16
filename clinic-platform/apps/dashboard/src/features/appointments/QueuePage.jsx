import AppointmentDetail from "./AppointmentDetail";
import { useState } from "react";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import {
  PageHeader,
  QueryState,
  Empty,
  Status,
  Failure,
} from "../../components/Shared";
import { clinicNow, clinicDate } from "../../utils/time";
export default function QueuePage() {
  const { clinic, access } = useClinic(),
    { t, text, locale } = useLocale();
  const [day, setDay] = useState(() => clinicNow(clinic.timezone).toISODate());
  const [detail, setDetail] = useState(null);
  const query = useAdminQuery("queue", { day });
  return (
    <>
      <PageHeader title={t("queue")} subtitle={t("queueHelp")} />
      <label>
        {t("date")}
        <input
          type="date"
          required
          value={day}
          onChange={(e) => e.target.value && setDay(e.target.value)}
        />
      </label>
      <QueryState query={query}>
        {(data) => (
          <section className="panel">
            {data.truncated && <p className="notice">{t("queueTruncated")}</p>}
            {!data.items?.length ? (
              <Empty />
            ) : (
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      {[
                        "patient",
                        "doctor",
                        "service",
                        "appointmentTime",
                        "status",
                        "actions",
                      ].map((k) => (
                        <th key={k}>{t(k)}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.map((a) => (
                      <tr key={a.id} data-appointment-id={a.id}>
                        <td>
                          <button
                            className="text-button"
                            onClick={() => setDetail(a.id)}
                          >
                            {a.patient_name}
                          </button>
                        </td>
                        <td>{text(a.doctor_name)}</td>
                        <td>{text(a.service_name)}</td>
                        <td>
                          {clinicDate(a.starts_at, clinic.timezone, locale)}
                        </td>
                        <td>
                          <Status value={a.attendance_status} />
                          <Status value={a.status} />
                        </td>
                        <td>
                          <Attendance appointment={a} role={access.role} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        )}
      </QueryState>
      {detail && (
        <AppointmentDetail id={detail} onClose={() => setDetail(null)} />
      )}
    </>
  );
}
function Attendance({ appointment: a, role }) {
  const { t } = useLocale();
  const mutation = useAdminMutation(`appointments/${a.id}/attendance`, "patch");
  const transitions = {
    scheduled: ["arrived"],
    arrived: ["waiting", "in_consultation"],
    waiting: ["in_consultation"],
    in_consultation: ["finished"],
  };
  const actions =
    a.status !== "confirmed"
      ? []
      : (transitions[a.attendance_status] || []).filter((s) =>
          role === "DOCTOR"
            ? ["in_consultation", "finished"].includes(s)
            : role === "RECEPTIONIST"
              ? ["arrived", "waiting"].includes(s)
              : true,
        );
  return (
    <>
      {actions.map((status) => (
        <button
          className="button secondary"
          key={status}
          disabled={mutation.isPending}
          onClick={() => {
            if (window.confirm(t("confirmAction") + " · " + t(status)))
              mutation.mutate({ status, expected_updated_at: a.updated_at });
          }}
        >
          {t(status)}
        </button>
      ))}
      {mutation.error && <Failure error={mutation.error} />}
    </>
  );
}
