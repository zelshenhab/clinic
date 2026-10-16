import { pageLoaders } from "./loaders";
import { lazy, Suspense } from "react";
import { Routes, Route } from "react-router-dom";
import { useClinic } from "../contexts/ClinicContext";
import { allowed } from "../utils/permissions";
import { Failure, Skeleton } from "../components/Shared";
const OverviewPage = lazy(pageLoaders.overview);
const AppointmentsPage = lazy(pageLoaders.appointments);
const CalendarPage = lazy(pageLoaders.calendar);
const CatalogPage = lazy(pageLoaders.catalog);
const PatientsPage = lazy(pageLoaders.patients);
const SchedulesPage = lazy(pageLoaders.schedules);
const SettingsPage = lazy(pageLoaders.settings);
const StaffPage = lazy(pageLoaders.staff);
const DoctorPages = Object.fromEntries(
  [
    "DoctorOverview",
    "DoctorPatients",
    "DoctorSchedule",
    "DoctorNotifications",
    "DoctorProfile",
    "DoctorSettings",
  ].map((name) => [
    name,
    lazy(() =>
      pageLoaders.doctor().then((m) => ({
        default: m[name],
      })),
    ),
  ]),
);
function DoctorRoutes() {
  return (
    <Routes>
      <Route index element={<DoctorPages.DoctorOverview />} />
      <Route path="appointments" element={<AppointmentsPage />} />
      <Route path="calendar" element={<CalendarPage />} />
      <Route path="patients" element={<DoctorPages.DoctorPatients />} />
      <Route path="schedules" element={<DoctorPages.DoctorSchedule />} />
      <Route
        path="notifications"
        element={<DoctorPages.DoctorNotifications />}
      />
      <Route path="profile" element={<DoctorPages.DoctorProfile />} />
      <Route path="settings" element={<DoctorPages.DoctorSettings />} />
      <Route path="*" element={<Failure error={{ code: "NOT_FOUND" }} />} />
    </Routes>
  );
}
function Permit({ operation, children }) {
  const { clinic, access } = useClinic();
  if (!allowed(access?.role, operation))
    return <Failure error={{ code: "FORBIDDEN" }} />;
  return <div key={clinic.id}>{children}</div>;
}
export function ManagementRoutes() {
  const { access, clinic } = useClinic();
  if (access?.role === "DOCTOR")
    return (
      <Suspense fallback={<Skeleton />}>
        <div key={clinic.id}>
          <DoctorRoutes />
        </div>
      </Suspense>
    );
  return (
    <Suspense fallback={<Skeleton />}>
      <Routes>
        <Route
          index
          element={
            <Permit operation="overview">
              <OverviewPage />
            </Permit>
          }
        />
        <Route
          path="appointments"
          element={
            <Permit operation="appointments">
              <AppointmentsPage />
            </Permit>
          }
        />
        <Route
          path="calendar"
          element={
            <Permit operation="calendar">
              <CalendarPage />
            </Permit>
          }
        />
        {["doctors", "specialties", "services", "promotions"].map(
          (resource) => (
            <Route
              key={resource}
              path={resource}
              element={
                <Permit operation="catalog">
                  <CatalogPage key={resource} resource={resource} />
                </Permit>
              }
            />
          ),
        )}
        <Route
          path="patients"
          element={
            <Permit operation="patients">
              <PatientsPage />
            </Permit>
          }
        />
        <Route
          path="schedules"
          element={
            <Permit operation="schedules">
              <SchedulesPage />
            </Permit>
          }
        />
        <Route
          path="settings"
          element={
            <Permit operation="settings">
              <SettingsPage />
            </Permit>
          }
        />
        <Route
          path="staff"
          element={
            <Permit operation="staff">
              <StaffPage />
            </Permit>
          }
        />
        <Route path="*" element={<Failure error={{ code: "NOT_FOUND" }} />} />
      </Routes>
    </Suspense>
  );
}
