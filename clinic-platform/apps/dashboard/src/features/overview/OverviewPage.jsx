import ClinicAnalytics from "./ClinicAnalytics";
import { useState } from "react";
import {
  CalendarCheck,
  CalendarDays,
  Clock,
  CheckCheck,
  Stethoscope,
  Users,
  ArrowUpRight,
} from "lucide-react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  CartesianGrid,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { useAdminQuery } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import { clinicNow, clinicDate } from "../../utils/time";
import {
  QueryState,
  Empty,
  DataTable,
  Status,
  PageHeader,
} from "../../components/Shared";
import { Link } from "react-router-dom";
export default function OverviewPage() {
  const { clinic, access } = useClinic(),
    { t, text, locale } = useLocale();
  const today = clinicNow(clinic.timezone).toISODate();
  const [preset, setPreset] = useState("last7"),
    [custom, setCustom] = useState({ from: today, to: today });
  const params =
    preset === "custom"
      ? custom
      : {
          from: clinicNow(clinic.timezone)
            .minus({
              days: preset === "last30" ? 29 : preset === "last7" ? 6 : 0,
            })
            .toISODate(),
          to: today,
        };
  const query = useAdminQuery("dashboard", params),
    options = useAdminQuery("options");
  const columns = [
    { key: "patient_name" },
    { key: "doctor_name", render: (r) => text(r.doctor_name) },
    {
      key: "starts_at",
      render: (r) => clinicDate(r.starts_at, clinic.timezone, locale),
    },
    { key: "status", render: (r) => <Status value={r.status} /> },
  ];
  return (
    <>
      <PageHeader
        title={t("overview")}
        subtitle={t("overviewSubtitle")}
        actions={
          <Link className="button" to="/appointments">
            {t("appointments")}
            <ArrowUpRight size={17} />
          </Link>
        }
      />
      <div className="date-toolbar">
        <div className="segmented">
          {["today", "last7", "last30", "custom"].map((p) => (
            <button
              key={p}
              className={preset === p ? "selected" : ""}
              onClick={() => setPreset(p)}
            >
              {t(p)}
            </button>
          ))}
        </div>
        {preset === "custom" && (
          <div className="inline-fields">
            <label>
              {t("from")}
              <input
                type="date"
                value={custom.from}
                onChange={(e) => setCustom({ ...custom, from: e.target.value })}
              />
            </label>
            <label>
              {t("to")}
              <input
                type="date"
                value={custom.to}
                onChange={(e) => setCustom({ ...custom, to: e.target.value })}
              />
            </label>
          </div>
        )}
      </div>
      <QueryState query={query}>
        {(data) => (
          <>
            <div className="kpi-grid">
              {[
                ["today", CalendarDays],
                ["upcoming", Clock],
                ["pending", Clock],
                ["confirmed", CalendarCheck],
                ["completed", CheckCheck],
                ["cancelled", CalendarDays],
                ["doctors", Stethoscope],
                ["patients", Users],
              ].map(([key, Icon], i) => (
                <article
                  className={`kpi ${i === 0 ? "primary" : ""}`}
                  key={key}
                >
                  <div>
                    <span>{t(key)}</span>
                    <Icon size={20} />
                  </div>
                  <strong>{data.kpis[key]}</strong>
                  <small>
                    {i < 2
                      ? t("clinicTimezone")
                      : params.from + " — " + params.to}
                  </small>
                </article>
              ))}
            </div>
            <div className="chart-grid">
              <Chart title={t("daily")} empty={!data.daily.length}>
                <ResponsiveContainer width="100%" height={250}>
                  <AreaChart data={data.daily}>
                    <defs>
                      <linearGradient id="blueArea" x1="0" y1="0" x2="0" y2="1">
                        <stop
                          offset="0%"
                          stopColor="#1677D2"
                          stopOpacity={0.3}
                        />
                        <stop
                          offset="100%"
                          stopColor="#1677D2"
                          stopOpacity={0}
                        />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis dataKey="day" />
                    <YAxis allowDecimals={false} />
                    <Tooltip />
                    <Area
                      isAnimationActive={false}
                      type="monotone"
                      dataKey="count"
                      name={t("count")}
                      stroke="#1677D2"
                      strokeWidth={3}
                      fill="url(#blueArea)"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </Chart>
              <Chart title={t("statuses")} empty={!data.statuses.length}>
                <ResponsiveContainer width="100%" height={250}>
                  <PieChart>
                    <Pie
                      isAnimationActive={false}
                      data={data.statuses.map((s) => ({
                        ...s,
                        label: t(s.status),
                      }))}
                      dataKey="count"
                      nameKey="label"
                      innerRadius={65}
                      outerRadius={95}
                    >
                      {data.statuses.map((s, i) => (
                        <Cell
                          key={s.status}
                          fill={
                            [
                              "#1677D2",
                              "#6AC3AE",
                              "#F2BC68",
                              "#D98F96",
                              "#7584A7",
                            ][i % 5]
                          }
                        />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
                <div className="chart-legend">
                  {data.statuses.map((s) => (
                    <Status key={s.status} value={s.status} />
                  ))}
                </div>
              </Chart>
              <Chart title={t("monthly")} empty={!data.monthly.length}>
                <ResponsiveContainer width="100%" height={250}>
                  <BarChart data={data.monthly}>
                    <XAxis dataKey="month" />
                    <YAxis allowDecimals={false} />
                    <Tooltip />
                    <Bar
                      isAnimationActive={false}
                      dataKey="count"
                      name={t("count")}
                      fill="#1677D2"
                      radius={[8, 8, 0, 0]}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </Chart>
              {[
                ["specialties", "topSpecialties"],
                ["services", "topServices"],
                ["workload", "workload"],
              ].map(([key, title]) => (
                <Chart key={key} title={t(title)} empty={!data[key].length}>
                  <div className="rank-list">
                    {data[key].map((r, i) => (
                      <div key={i}>
                        <span className="rank">{i + 1}</span>
                        <strong>{text(r.name)}</strong>
                        <span>{r.count}</span>
                      </div>
                    ))}
                  </div>
                </Chart>
              ))}
            </div>
            <div className="overview-lists">
              {["today", "recent", "upcoming"].map((key) => (
                <section className="panel" key={key}>
                  <div className="panel-heading">
                    <h2>{t(key)}</h2>
                    <Link to="/appointments">{t("view")} →</Link>
                  </div>
                  <DataTable columns={columns} rows={data[key]} />
                </section>
              ))}
            </div>
            {access.role === "SUPER_ADMIN" && (
              <ClinicAnalytics params={params} />
            )}
            <section className="panel">
              <h2>{t("availableDoctors")}</h2>
              <p className="muted">{t("scheduleAvailabilityNote")}</p>
              <QueryState query={options}>
                {(o) => (
                  <div className="doctor-chips">
                    {o.doctors.map((d) => (
                      <span key={d.id}>
                        <Stethoscope size={17} />
                        {text(d.name)}
                      </span>
                    ))}
                  </div>
                )}
              </QueryState>
            </section>
          </>
        )}
      </QueryState>
    </>
  );
}
function Chart({ title, empty, children }) {
  return (
    <section className="panel chart">
      <h2>{title}</h2>
      {empty ? <Empty /> : children}
    </section>
  );
}
