export const pageLoaders = {
  overview: () => import("../features/overview/OverviewPage"),
  appointments: () => import("../features/appointments/AppointmentsPage"),
  calendar: () => import("../features/appointments/CalendarPage"),
  catalog: () => import("../features/catalog/CatalogPage"),
  patients: () => import("../features/appointments/PatientsPage"),
  schedules: () => import("../features/schedules/SchedulesPage"),
  settings: () => import("../features/settings/SettingsPage"),
  staff: () => import("../features/staff/StaffPage"),
  doctor: () => import("../features/doctor/DoctorPages"),
};
export function preloadPage(path, role) {
  const name =
    role === "DOCTOR" && !["appointments", "calendar"].includes(path)
      ? "doctor"
      : ["doctors", "specialties", "services", "promotions"].includes(path)
        ? "catalog"
        : path || "overview";
  return pageLoaders[name]?.();
}
