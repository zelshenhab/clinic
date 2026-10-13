import { useState } from "react";
import { Plus, Search } from "lucide-react";
import { useAdminQuery } from "../../hooks/useAdmin";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import { useDebounced } from "../../hooks/useDebounced";
import { clinicDate, toInstant } from "../../utils/time";
import { DateTime } from "luxon";
import { allowed } from "../../utils/permissions";
import {
  Failure,
  QueryState,
  DataTable,
  Status,
  Pagination,
  PageHeader,
  Dialog,
} from "../../components/Shared";
import BookingForm from "./BookingForm";
import AppointmentDetail from "./AppointmentDetail";
export default function AppointmentsPage() {
  const { clinic, access } = useClinic(),
    { t, text, locale } = useLocale();
  const [search, setSearch] = useState(""),
    [filters, setFilters] = useState({}),
    [page, setPage] = useState(1),
    [detail, setDetail] = useState(null),
    [create, setCreate] = useState(false);
  const term = useDebounced(search);
  const query = useAdminQuery("appointments", {
      ...filters,
      search: term,
      page,
      limit: 20,
    }),
    options = useAdminQuery("filter-options");
  function filter(key, value) {
    setFilters((v) => {
      const next = { ...v };
      if (value) next[key] = value;
      else delete next[key];
      return next;
    });
    setPage(1);
  }
  const columns = [
    {
      key: "id",
      render: (r) => (
        <button className="text-button" onClick={() => setDetail(r.id)}>
          #{r.id.slice(0, 8)}
        </button>
      ),
    },
    { key: "patient_name" },
    { key: "patient_phone" },
    { key: "doctor_name", render: (r) => text(r.doctor_name) },
    { key: "specialty_name", render: (r) => text(r.specialty_name) },
    { key: "service_name", render: (r) => text(r.service_name) },
    {
      key: "starts_at",
      render: (r) => clinicDate(r.starts_at, clinic.timezone, locale),
    },
    { key: "status", render: (r) => <Status value={r.status} /> },
    {
      key: "created_at",
      render: (r) => clinicDate(r.created_at, clinic.timezone, locale),
    },
    {
      key: "actions",
      render: (r) => (
        <button className="text-button" onClick={() => setDetail(r.id)}>
          {t("view")}
        </button>
      ),
    },
  ];
  return (
    <>
      <PageHeader
        title={t(access.role === "DOCTOR" ? "myAppointments" : "appointments")}
        subtitle={t("bookingHelp")}
        actions={
          allowed(access.role, "book") && (
            <button className="button" onClick={() => setCreate(true)}>
              <Plus size={18} />
              {t("book")}
            </button>
          )
        }
      />
      <section className="panel">
        {options.error && (
          <Failure error={options.error} retry={options.refetch} />
        )}
        {access.role === "DOCTOR" && (
          <div className="segmented">
            {["today", "tomorrow", "thisWeek", "customRange"].map((p) => (
              <button
                key={p}
                onClick={() => {
                  const now = DateTime.now().setZone(clinic.timezone),
                    start =
                      p === "thisWeek"
                        ? now.startOf("week")
                        : p === "tomorrow"
                          ? now.plus({ days: 1 }).startOf("day")
                          : now.startOf("day");
                  setFilters((v) => {
                    const { from, to, ...rest } = v;
                    return p === "customRange"
                      ? rest
                      : {
                          ...rest,
                          from: start.toUTC().toISO(),
                          to: start
                            .plus({ days: p === "thisWeek" ? 7 : 1 })
                            .toUTC()
                            .toISO(),
                        };
                  });
                  setPage(1);
                }}
              >
                {t(p)}
              </button>
            ))}
          </div>
        )}
        <div className="filter-grid">
          <label className="search-input">
            <Search size={17} />
            <input
              aria-label={t("search")}
              placeholder={t("patientSearch")}
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </label>
          <select
            aria-label={t("status")}
            value={filters.status || ""}
            onChange={(e) => filter("status", e.target.value)}
          >
            <option value="">{t("allStatuses")}</option>
            {["pending", "confirmed", "completed", "cancelled", "no_show"].map(
              (s) => (
                <option key={s} value={s}>
                  {t(s)}
                </option>
              ),
            )}
          </select>
          {access.role !== "DOCTOR" && (
            <select
              aria-label={t("doctor")}
              value={filters.doctor_id || ""}
              onChange={(e) => filter("doctor_id", e.target.value)}
            >
              <option value="">{t("allDoctors")}</option>
              {options.data?.doctors.map((d) => (
                <option key={d.id} value={d.id}>
                  {text(d.name)}
                </option>
              ))}
            </select>
          )}
          {access.role !== "DOCTOR" && (
            <select
              aria-label={t("specialty")}
              value={filters.specialty_id || ""}
              onChange={(e) => filter("specialty_id", e.target.value)}
            >
              <option value="">
                {t("specialty")}: {t("all")}
              </option>
              {options.data?.specialties.map((s) => (
                <option key={s.id} value={s.id}>
                  {text(s.name)}
                </option>
              ))}
            </select>
          )}
          <select
            aria-label={t("service")}
            value={filters.service_id || ""}
            onChange={(e) => filter("service_id", e.target.value)}
          >
            <option value="">
              {t("service")}: {t("all")}
            </option>
            {options.data?.services.map((s) => (
              <option key={s.id} value={s.id}>
                {text(s.name)}
              </option>
            ))}
          </select>
          <select
            aria-label={t("sort")}
            value={filters.sort || "newest"}
            onChange={(e) => filter("sort", e.target.value)}
          >
            {["newest", "oldest"].map((s) => (
              <option key={s} value={s}>
                {t(s)}
              </option>
            ))}
          </select>
          <label>
            {t("from")}
            <input
              type="date"
              onChange={(e) =>
                filter(
                  "from",
                  e.target.value
                    ? DateTime.fromISO(e.target.value, {
                        zone: clinic.timezone,
                      })
                        .startOf("day")
                        .toUTC()
                        .toISO()
                    : "",
                )
              }
            />
          </label>
          <label>
            {t("to")}
            <input
              type="date"
              onChange={(e) =>
                filter(
                  "to",
                  e.target.value
                    ? DateTime.fromISO(e.target.value, {
                        zone: clinic.timezone,
                      })
                        .plus({ days: 1 })
                        .startOf("day")
                        .toUTC()
                        .toISO()
                    : "",
                )
              }
            />
          </label>
        </div>
        <QueryState query={query}>
          {(data) => (
            <>
              <DataTable
                rows={data.items}
                columns={
                  access.role === "DOCTOR"
                    ? [
                        columns[1],
                        {
                          key: "appointmentDate",
                          render: (r) =>
                            DateTime.fromISO(r.starts_at)
                              .setZone(clinic.timezone)
                              .setLocale(locale)
                              .toLocaleString(DateTime.DATE_MED),
                        },
                        {
                          key: "appointmentTime",
                          render: (r) =>
                            DateTime.fromISO(r.starts_at)
                              .setZone(clinic.timezone)
                              .toFormat("HH:mm"),
                        },
                        columns[5],
                        columns[7],
                        columns[0],
                        columns[9],
                      ]
                    : columns
                }
              />
              <Pagination value={data.pagination} onPage={setPage} />
            </>
          )}
        </QueryState>
      </section>
      {create && (
        <Dialog title={t("book")} onClose={() => setCreate(false)}>
          <BookingForm onDone={() => setCreate(false)} />
        </Dialog>
      )}
      {detail && (
        <AppointmentDetail id={detail} onClose={() => setDetail(null)} />
      )}
    </>
  );
}
