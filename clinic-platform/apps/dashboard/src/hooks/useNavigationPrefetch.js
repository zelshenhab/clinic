import { useQueryClient } from "@tanstack/react-query";
import { useClinic } from "../contexts/ClinicContext";
import { adminQueryOptions, doctorQueryOptions } from "../services/queries";
import { preloadPage } from "../routes/loaders";
import { clinicNow, rangeFor } from "../utils/time";
export function navigationReads(path, clinic, access) {
  const doctor = access?.role === "DOCTOR",
    admin = (p, q = {}) => adminQueryOptions(clinic, access, p, q),
    own = (p, q = {}) => doctorQueryOptions(clinic, access, p, q),
    list = { search: "", page: 1, limit: 20 },
    today = clinicNow(clinic.timezone);
  if (path === "appointments")
    return [admin("appointments", list), admin("filter-options")];
  if (path === "calendar") {
    const range = rangeFor(today.toISODate(), "week", clinic.timezone);
    return [
      admin("calendar", { from: range.from, to: range.to }),
      admin("filter-options"),
    ];
  }
  if (doctor) {
    if (!path) {
      const week = today.startOf("week");
      return [
        own("dashboard", {
          from: week.toISODate(),
          to: week.plus({ days: 6 }).toISODate(),
        }),
      ];
    }
    if (path === "patients") return [own("patients", list)];
    if (path === "schedules")
      return [own("schedule"), own("requests", { page: 1, limit: 20 })];
    if (path === "notifications")
      return [own("notifications", { page: 1, limit: 20 })];
    if (path === "profile") return [own("me")];
    return [];
  }
  if (
    ["doctors", "specialties", "services", "promotions", "patients"].includes(
      path,
    )
  )
    return [admin(path, list)];
  if (path === "settings") return [admin("settings")];
  if (path === "staff") return [admin("staff", { page: 1, limit: 20 })];
  if (path === "schedules")
    return [
      admin("schedule-options"),
      admin("doctor-requests", { page: 1, limit: 20, status: "pending" }),
    ];
  if (!path)
    return [
      admin("dashboard", {
        from: today.minus({ days: 6 }).toISODate(),
        to: today.toISODate(),
      }),
      admin("options"),
    ];
  return [];
}
export function useNavigationPrefetch() {
  const client = useQueryClient(),
    { clinic, access } = useClinic();
  return (path) => {
    if (!clinic || !access) return;
    void preloadPage(path, access.role)?.catch(() => {});
    for (const query of navigationReads(path, clinic, access))
      void client.prefetchQuery({ ...query, retry: false });
  };
}
