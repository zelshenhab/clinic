# Phase 5 source inventory

- `apps/dashboard/src/app/App.jsx`
- `apps/dashboard/src/components/FormFields.jsx`
- `apps/dashboard/src/components/Shared.jsx`
- `apps/dashboard/src/contexts/AuthContext.jsx`
- `apps/dashboard/src/contexts/ClinicContext.jsx`
- `apps/dashboard/src/contexts/ClinicContext.test.jsx`
- `apps/dashboard/src/contexts/LocaleContext.jsx`
- `apps/dashboard/src/contexts/ToastContext.jsx`
- `apps/dashboard/src/features/appointments/AppointmentDetail.jsx`
- `apps/dashboard/src/features/appointments/AppointmentsPage.jsx`
- `apps/dashboard/src/features/appointments/BookingForm.jsx`
- `apps/dashboard/src/features/appointments/BookingForm.test.jsx`
- `apps/dashboard/src/features/appointments/CalendarPage.jsx`
- `apps/dashboard/src/features/appointments/PatientsPage.jsx`
- `apps/dashboard/src/features/authentication/LoginPage.jsx`
- `apps/dashboard/src/features/authentication/PasswordSetup.jsx`
- `apps/dashboard/src/features/catalog/CatalogPage.jsx`
- `apps/dashboard/src/features/overview/ClinicAnalytics.jsx`
- `apps/dashboard/src/features/overview/OverviewPage.jsx`
- `apps/dashboard/src/features/schedules/SchedulesPage.jsx`
- `apps/dashboard/src/features/settings/SettingsPage.jsx`
- `apps/dashboard/src/features/staff/StaffPage.jsx`
- `apps/dashboard/src/features/staff/SystemSettings.jsx`
- `apps/dashboard/src/hooks/useAdmin.js`
- `apps/dashboard/src/hooks/useAppointmentRealtime.js`
- `apps/dashboard/src/hooks/useAppointmentRealtime.test.jsx`
- `apps/dashboard/src/hooks/useDebounced.js`
- `apps/dashboard/src/layouts/Layout.jsx`
- `apps/dashboard/src/main.jsx`
- `apps/dashboard/src/routes/ManagementRoutes.jsx`
- `apps/dashboard/src/services/api.js`
- `apps/dashboard/src/services/api.test.js`
- `apps/dashboard/src/services/supabase.js`
- `apps/dashboard/src/style.css`
- `apps/dashboard/src/utils/calendarLayout.js`
- `apps/dashboard/src/utils/calendarLayout.test.js`
- `apps/dashboard/src/utils/formSchemas.js`
- `apps/dashboard/src/utils/localization.js`
- `apps/dashboard/src/utils/localization.test.js`
- `apps/dashboard/src/utils/permissions.js`
- `apps/dashboard/src/utils/time.js`
- `apps/dashboard/src/utils/time.test.js`
- `apps/dashboard/src/utils/translations.js`
- `apps/dashboard/tests/browser.mjs`
- `backend/src/modules/admin/permissions.ts`
- `backend/src/modules/admin/repository.ts`
- `backend/src/modules/admin/routes.ts`
- `backend/src/modules/admin/service.ts`
- `backend/src/modules/admin/uploads.ts`
- `backend/src/modules/admin/validation.ts`
- `backend/src/modules/appointments/routes.ts`
- `backend/tests/admin-http.test.ts`
- `backend/tests/admin-permissions.test.ts`
- `backend/tests/admin-upload.test.ts`
- `backend/tests/database.test.ts`
- `backend/tests/support/browser-api.ts`
- `supabase/migrations/202610120004_staff_booking.sql`
- `supabase/migrations/202610120005_admin_management.sql`
- `supabase/migrations/202610120006_shared_booking_system.sql`

## Doctor extension

- `apps/dashboard/src/features/doctor/DoctorPages.jsx`
- `apps/dashboard/src/features/doctor/RequestReview.jsx`
- `apps/dashboard/src/features/doctor/RescheduleRequest.jsx`
- `apps/dashboard/src/features/doctor/WorkingHours.jsx`
- `apps/dashboard/src/hooks/useAdmin.doctor.test.jsx`
- `apps/dashboard/src/hooks/useDoctor.js`
- `apps/dashboard/tests/doctor-browser.mjs`
- `backend/src/modules/doctor/routes.ts`
- `docs/phase-5-doctor.md`
- `supabase/migrations/202610130007_doctor_workspace.sql`

## Availability and performance update

See [delivery](availability-and-performance.md), `apps/dashboard/src/services/queries.js`, `apps/dashboard/src/hooks/useNavigationPrefetch.js`, `backend/src/common/async/in-flight.ts`, `supabase/migrations/202610160008_doctor_availability.sql` and the mobile appointments domain/data/presentation booking flow.
