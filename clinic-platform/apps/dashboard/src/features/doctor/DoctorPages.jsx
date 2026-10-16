import WorkingHours from "./WorkingHours";
import { useState } from "react";
import { DateTime } from "luxon";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { useDoctorQuery, useDoctorMutation } from "../../hooks/useDoctor";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import { useAuth } from "../../contexts/AuthContext";
import { useDebounced } from "../../hooks/useDebounced";
import {
  PageHeader,
  QueryState,
  DataTable,
  Pagination,
  Status,
  Dialog,
  Failure,
  Submit,
  Empty,
} from "../../components/Shared";
import { clinicDate, clinicNow, toInstant } from "../../utils/time";
import AppointmentDetail from "../appointments/AppointmentDetail";
import { ScheduleEditor } from "../schedules/SchedulesPage";
export function DoctorOverview() {
  const { t, text, locale } = useLocale(),
    { clinic } = useClinic(),
    week = clinicNow(clinic.timezone).startOf("week"),
    q = useDoctorQuery("dashboard", {
      from: week.toISODate(),
      to: week.plus({ days: 6 }).toISODate(),
    }),
    [detail, setDetail] = useState(null);
  const appointment = (a) => (
    <button
      className="doctor-timeline-item"
      key={a.id}
      onClick={() => setDetail(a.id)}
    >
      <time>{clinicDate(a.starts_at, clinic.timezone, locale)}</time>
      <strong>{a.patient_name}</strong>
      <span>{text(a.service_name)}</span>
      <Status value={a.status} />
    </button>
  );
  return (
    <>
      <PageHeader
        title={t("doctorOverview")}
        subtitle={t("doctorOverviewHelp")}
      />
      <QueryState query={q}>
        {(d) => (
          <>
            <div className="kpi-grid">
              {[
                "today",
                "upcoming",
                "confirmed",
                "pending",
                "completed",
                "cancelled",
                "patients",
              ].map((k) => (
                <section className="kpi" key={k}>
                  <small>{t(k === "patients" ? "uniquePatients" : k)}</small>
                  <strong>{d.kpis[k]}</strong>
                  <small>
                    {[
                      "pending",
                      "confirmed",
                      "completed",
                      "cancelled",
                    ].includes(k)
                      ? t("thisWeek")
                      : t("myAppointments")}
                  </small>
                </section>
              ))}
            </div>
            <section className="panel">
              <h3>{t("nextAppointment")}</h3>
              {d.next ? appointment(d.next) : <Empty />}
            </section>
            <div className="charts-grid">
              <section className="panel">
                <h3>{t("weeklySummary")}</h3>
                <ResponsiveContainer width="100%" height={240}>
                  <BarChart data={d.daily}>
                    <XAxis dataKey="day" />
                    <YAxis allowDecimals={false} />
                    <Tooltip />
                    <Bar
                      dataKey="count"
                      fill="#1677D2"
                      isAnimationActive={false}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </section>
              <section className="panel">
                <h3>{t("statuses")}</h3>
                <ResponsiveContainer width="100%" height={240}>
                  <PieChart>
                    <Pie
                      data={d.statuses.map((s) => ({
                        ...s,
                        label: t(s.status),
                      }))}
                      nameKey="label"
                      dataKey="count"
                      innerRadius={55}
                      isAnimationActive={false}
                    >
                      {d.statuses.map((s, i) => (
                        <Cell
                          key={s.status}
                          fill={
                            [
                              "#1677D2",
                              "#36B6A5",
                              "#FFB547",
                              "#8B7CF6",
                              "#EB647A",
                            ][i]
                          }
                        />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </section>
            </div>
            <section className="panel">
              <h3>{t("todayTimeline")}</h3>
              {d.today.length ? d.today.map(appointment) : <Empty />}
              {d.kpis.today > d.today.length && (
                <p>{t("viewAllAppointments")}</p>
              )}
            </section>
            <WorkingHours data={d.schedule} />
          </>
        )}
      </QueryState>
      {detail && (
        <AppointmentDetail id={detail} onClose={() => setDetail(null)} />
      )}
    </>
  );
}
export function DoctorPatients() {
  const { t, locale } = useLocale(),
    { clinic } = useClinic(),
    [search, setSearch] = useState(""),
    [page, setPage] = useState(1),
    [patient, setPatient] = useState(null),
    q = useDoctorQuery("patients", {
      search: useDebounced(search),
      page,
      limit: 20,
    });
  return (
    <>
      <PageHeader
        title={t("myPatients")}
        subtitle={t("patientRelationshipHelp")}
      />
      <section className="panel">
        <input
          aria-label={t("search")}
          placeholder={t("search")}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
        <QueryState query={q}>
          {(d) => (
            <>
              <DataTable
                rows={d.items}
                columns={[
                  { key: "full_name" },
                  {
                    key: "last_appointment",
                    render: (r) =>
                      r.last_appointment
                        ? clinicDate(
                            r.last_appointment,
                            clinic.timezone,
                            locale,
                          )
                        : "—",
                  },
                  {
                    key: "next_appointment",
                    render: (r) =>
                      r.next_appointment
                        ? clinicDate(
                            r.next_appointment,
                            clinic.timezone,
                            locale,
                          )
                        : "—",
                  },
                  { key: "appointment_count" },
                  {
                    key: "actions",
                    render: (r) => (
                      <button
                        className="text-button"
                        onClick={() => setPatient(r)}
                      >
                        {t("history")}
                      </button>
                    ),
                  },
                ]}
              />
              <Pagination value={d.pagination} onPage={setPage} />
            </>
          )}
        </QueryState>
      </section>
      {patient && (
        <PatientHistory patient={patient} onClose={() => setPatient(null)} />
      )}
    </>
  );
}
function PatientHistory({ patient, onClose }) {
  const { t, text, locale } = useLocale(),
    { clinic } = useClinic(),
    [page, setPage] = useState(1),
    q = useDoctorQuery("appointments", {
      patient_id: patient.id,
      page,
      limit: 20,
    }),
    [detail, setDetail] = useState(null);
  return (
    <Dialog title={patient.full_name} onClose={onClose}>
      <QueryState query={q}>
        {(d) => (
          <>
            <DataTable
              rows={d.items}
              columns={[
                {
                  key: "starts_at",
                  render: (r) =>
                    clinicDate(r.starts_at, clinic.timezone, locale),
                },
                { key: "service_name", render: (r) => text(r.service_name) },
                { key: "status", render: (r) => <Status value={r.status} /> },
                {
                  key: "actions",
                  render: (r) => (
                    <button
                      className="text-button"
                      onClick={() => setDetail(r.id)}
                    >
                      {t("view")}
                    </button>
                  ),
                },
              ]}
            />
            <Pagination value={d.pagination} onPage={setPage} />
          </>
        )}
      </QueryState>
      {detail && (
        <AppointmentDetail id={detail} onClose={() => setDetail(null)} />
      )}
    </Dialog>
  );
}
export function DoctorSchedule() {
  const { t } = useLocale(),
    { access } = useClinic(),
    q = useDoctorQuery("schedule");
  return (
    <>
      <PageHeader title={t("mySchedule")} subtitle={t("directScheduleHelp")} />
      <QueryState query={q}>
        {(d) => (
          <>
            <WorkingHours data={d} />
            <h2>{t("editAvailability")}</h2>
            <ScheduleEditor
              key={JSON.stringify(d)}
              doctor={access.doctor_id}
              data={d}
              doctorDirect
            />
          </>
        )}
      </QueryState>
      <DoctorRequests />
    </>
  );
}
export function DoctorRequests() {
  const { t, locale } = useLocale(),
    { clinic } = useClinic(),
    [page, setPage] = useState(1),
    q = useDoctorQuery("requests", { page, limit: 20 });
  return (
    <section className="panel">
      <h3>{t("myRequests")}</h3>
      <QueryState query={q}>
        {(d) => (
          <>
            <DataTable
              rows={d.items}
              columns={[
                { key: "kind", render: (r) => t("request_" + r.kind) },
                { key: "reason" },
                { key: "status", render: (r) => <Status value={r.status} /> },
                { key: "review_note" },
                {
                  key: "created_at",
                  render: (r) =>
                    clinicDate(r.created_at, clinic.timezone, locale),
                },
              ]}
            />
            <Pagination value={d.pagination} onPage={setPage} />
          </>
        )}
      </QueryState>
    </section>
  );
}
export function DoctorNotifications() {
  const { t, locale } = useLocale(),
    { clinic } = useClinic(),
    [page, setPage] = useState(1),
    [detail, setDetail] = useState(null),
    q = useDoctorQuery("notifications", { page, limit: 20 });
  return (
    <>
      <PageHeader
        title={t("notifications")}
        subtitle={t("doctorNotificationsHelp")}
      />
      <section className="panel">
        <QueryState query={q}>
          {(d) => (
            <>
              <DataTable
                rows={d.items}
                columns={[
                  { key: "action", render: (r) => t(r.action) },
                  {
                    key: "created_at",
                    render: (r) =>
                      clinicDate(r.created_at, clinic.timezone, locale),
                  },
                  {
                    key: "actions",
                    render: (r) =>
                      r.appointment_id && (
                        <button
                          className="text-button"
                          onClick={() => setDetail(r.appointment_id)}
                        >
                          {t("view")}
                        </button>
                      ),
                  },
                ]}
              />
              <Pagination value={d.pagination} onPage={setPage} />
            </>
          )}
        </QueryState>
      </section>
      {detail && (
        <AppointmentDetail id={detail} onClose={() => setDetail(null)} />
      )}
    </>
  );
}
export function DoctorProfile() {
  const { t, text } = useLocale(),
    auth = useAuth(),
    { clinic } = useClinic(),
    q = useDoctorQuery("me");
  return (
    <>
      <PageHeader title={t("myProfile")} subtitle={t("profileManagedHelp")} />
      <QueryState query={q}>
        {(d) => (
          <section className="panel">
            <div className="detail-hero">
              <div>
                <h2>{text(d.name)}</h2>
                <p>{text(d.professional_title)}</p>
              </div>
            </div>
            <div className="detail-grid">
              {[
                ["email", auth.staff.email],
                ["clinic", text(clinic.name)],
                ["doctor", d.id],
                ["experience_years", d.experience_years],
                ["education", text(d.education)],
                ["qualifications", text(d.qualifications)],
                ["biography", text(d.biography)],
              ].map(([k, v]) => (
                <div key={k}>
                  <small>{t(k)}</small>
                  <strong>{v || "—"}</strong>
                </div>
              ))}
            </div>
          </section>
        )}
      </QueryState>
    </>
  );
}
export function DoctorSettings() {
  const { t, locale, change } = useLocale();
  return (
    <>
      <PageHeader
        title={t("doctorSettings")}
        subtitle={t("personalSettings")}
      />
      <section className="panel">
        <label>
          {t("language")}
          <select value={locale} onChange={(e) => change(e.target.value)}>
            <option value="ru">Русский</option>
            <option value="en">English</option>
          </select>
        </label>
        <p>{t("notificationsPrivacyHelp")}</p>
      </section>
    </>
  );
}
