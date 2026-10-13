# Phase 5 extension: doctor workspace

Implemented in the existing React application and Node/Supabase architecture. No separate doctor frontend or database was introduced. Live-provider acceptance remains pending; the hosted project has not been migrated by this implementation session.

## Delivered behavior

Doctor-only clinic access automatically renders eight navigation entries: Overview, My Appointments, My Calendar, My Patients, My Schedule, Notifications, My Profile and personal Settings. Existing staff login, session persistence, refresh, logout and protected routing are reused. Accounts holding separately authorized administrative roles retain the administrative workspace for those assignments; doctor API operations stay doctor-scoped even for such accounts.

Overview calculates seven real SQL counters: today, upcoming, confirmed, pending, completed, cancelled and distinct patients. Status counters and charts use the clinic-local current week; today/upcoming and unique patients use the documented broader scope. It shows today's chronological appointments, next appointment, weekly/status charts and current working schedule. The today timeline caps 100 rows and directs larger lists to paginated My Appointments.

My Appointments includes patient name, separate date/time in clinic timezone, service, status, booking reference and details. Search, status/service filters, today/tomorrow/week/custom periods, sorting, pagination, loading, empty and retry states run through the authorized backend. The doctor calendar reuses day/week/month geometry and shows own shifts, breaks, days off and exceptions alongside appointments. The clinic selector provides isolation for doctors assigned to multiple clinics.

My Patients groups only actual appointment relationships with the authenticated doctor, including last/next appointment and appointment count. Patient history remains paginated and restricted to that doctor and clinic. The patient list omits general contact details; own appointment details permit the patient's operational phone contact. No diagnoses, medical records, unrelated patient profiles or general clinic patient lists are exposed. Booking notes and internal clinical notes were not added because the existing product has no separately authorized notes policy/model.

My Profile reads the assigned professional identity and clinic presentation; administrators continue managing account/identity assignments. Personal Settings persist Russian/English selection. Russian is the default. Notifications provide paginated durable appointment audit events and reviewed request outcomes; live event indicators continue using the shared private channel.

## Requests and administrator review

Doctors can request a complete weekly schedule change, day off, vacation interval or appointment rescheduling. Submitting a request never changes availability or appointments. Requests include a bounded reason and appear in My Schedule. Rescheduling requests originate from the doctor's own future pending/confirmed appointment and retain its expected update timestamp.

Authorized clinic administrators and super administrators review requests under Schedules. Review displays the doctor, reason, proposed schedule/interval, status and comment, and requires confirmation. Doctors/receptionists cannot approve; a requester cannot approve their own request even with a separate administrator membership.

Approval locks the request, clinic and doctor and repeats authorization. Schedule approvals detect intervening schedule edits using a stored baseline. Leave approvals merge a negative exception into the current schedule and apply existing appointment-conflict validation. Rescheduling approvals call the same availability-checked booking mutation used by reception. A stale record, occupied slot or conflicting appointment rolls back the whole approval and leaves the request pending. Decisions and resulting schedule/appointment changes are audited.

Doctors can complete or mark no-show only their own confirmed appointments after the appointment starts. Direct cancellation and direct rescheduling remain administrator/reception operations. Histories, audits and appointment event emission use the existing transaction logic.

## Database and API

Incremental migration: [202610130007_doctor_workspace.sql](../supabase/migrations/202610130007_doctor_workspace.sql). It adds `doctor_change_requests`, server-only doctor/read/status/request/review functions, account-link validation and private request events. Existing composite doctor/clinic foreign keys remain authoritative. Active doctor account links require an active doctor_clinics assignment and cannot link one account to different doctor identities across clinics. Shared identities are reused, not duplicated.

New endpoints under `/api/v1/doctor`: GET me, dashboard, appointments, appointments/{id}, patients, patients/{id}, calendar, schedule, options, notifications and requests; POST schedule-change-requests; PATCH appointments/{id}/status. Requests use clinic_id; doctor_id is never accepted as authorization input. GET/PATCH administrator doctor-requests routes implement review. See [OpenAPI](openapi.yaml).

All doctor RPCs derive doctor identity from current active database membership and clinic assignment. Reads explicitly predicate both clinic_id and doctor_id, including for accounts with an additional admin membership. Browser database roles cannot read the new request table or invoke privileged functions. Node uses verified getUser identity, strict Zod input, consistent envelopes and sanitized errors.

## Realtime and Flutter integration

Appointments use the existing private `staff:clinic:user` channels with current recipients restricted to the assigned doctor. Request submission/review emits a separate minimal event to the relevant doctor and authorized clinic administrators. Payloads carry event/clinic/request or appointment identifiers, never patient details/reasons. The shared hook subscribes to both event types, deduplicates, debounces authorized refetches, invalidates after reconnect and clears channels/cache on clinic switch, identity change or logout.

The patient and staff booking SQL/API remain shared with Flutter. An integration test verifies patient_book commits an appointment visible to Doctor A and emits no private appointment event to Doctor B. Existing Flutter catalog/authentication behavior is preserved. Flutter Phase 4 booking UI and patient Realtime remain outstanding from the earlier delivery; this extension does not claim a live Flutter-to-hosted-WebSocket acceptance test.

## Verification

`npm run build` passed TypeScript and Vite. `npm test` passed **74 backend tests and 18 dashboard tests**. Expanded backend tests cover own/foreign appointment and patient reads, clinic assignments, accurate aggregate queries, calendar events/schedules, valid/rejected statuses, audited history, request review authorization, conflict rollback, stale schedule protection, direct browser database denial and private event audiences. Dashboard tests cover doctor endpoint mapping, bearer/session handling and private event lifecycle alongside all existing regressions. Flutter analyze reports no issues and all 43 Flutter tests pass.

Local Chrome verifies doctor login/eight pages, day/week/month calendar, schedule visibility, patient scoping, schedule/rescheduling requests, authorized review, durable notifications, clinic switching, RU/EN and mobile width. The existing administrator browser workflow is also verified. Browser Auth is controlled test-only; all business operations use actual Node routes and migrated PostgreSQL via PGlite. Hosted email/Auth/WebSocket delivery is not certified by those checks.

Screenshots use synthetic fixtures: [doctor overview](verification/doctor-overview.png), [doctor mobile](verification/doctor-mobile.png).

## Activate on the current Supabase project

Apply migration 007 once through the project's SQL Editor, after migrations 001–006. Do not rerun the initial full setup file. Restart the local Node/dashboard processes if needed. From the existing SUPER_ADMIN Staff page, invite or link a real Auth user, choose DOCTOR and the assigned doctor record for the selected clinic. For a second clinic, first assign the same global doctor identity to that clinic, then add the account's DOCTOR membership there. Do not place server keys in React or Flutter.

The new migration has not been executed against the hosted project during this session. Real accounts must be provisioned by the administrator; no fabricated doctor login is included. Hosted private-channel acceptance and end-to-end mobile booking remain explicit follow-up checks.
