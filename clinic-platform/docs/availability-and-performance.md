# Doctor availability, mobile booking and dashboard performance

Delivered on 2026-10-16. This supersedes the earlier requirement that every doctor schedule edit await administrator approval. The migration has been verified locally and has not been applied to the hosted Supabase project in this session.

## Doctor workflow

In My Schedule, doctors now directly save their own weekly days/shifts, breaks and date-specific exceptions. An unchecked Available exception blocks a period (time off/vacation); a checked exception opens an additional period. Days without a weekly shift are unavailable unless explicitly opened by an exception. All times are interpreted in the clinic timezone. Existing rescheduling requests and administrator request-history screens remain supported, but regular availability edits no longer create approval requests.

PUT `/api/v1/doctor/schedule` derives the doctor from the verified active account/clinic relationship. The SQL transaction locks the clinic and doctor, checks proposed hours/breaks/exceptions against ongoing and future active appointments, then saves and audits the schedule. A conflicting edit returns 409 with appointment references; it does not move/cancel existing bookings. Doctor identity cannot be submitted to select someone else's schedule.

## Patient workflow

Flutter booking preparation now includes date selection, real available slot chips, authenticated booking confirmation and a receipt with server-assigned booking reference/status/price. Public GET `/api/v1/clinics/{clinicId}/availability` exposes only intervals, never patient data. Selection is disabled during refresh/submission, and UTC timestamps preserve the exact chosen slot. Login/profile completion preserve the selected doctor/service through the existing OTP flow. Browsing slots requires no login; committing a booking still requires real patient authentication and a completed profile; first-time clinic membership is created atomically with that patient’s own booking. A configured SMS provider remains necessary for phone sign-in; there is no fake OTP or fabricated booking fallback.

Staff and patient booking still share the same SQL validator and transaction, including service duration/price, clinic timezone, weekly shifts, breaks, positive/negative exceptions, global booking horizon and global doctor overlap exclusion. Once booked, the slot is excluded from availability. A competing request receives a conflict. The Flutter Cubit prevents double taps, displays success only after commit, refetches after conflicts and rejects stale responses after clinic/logout scope changes.

## Automatic updates

Existing private `staff:clinic:user` events refresh the assigned doctor's appointments/calendar/statistics. Additional public `availability:clinic:doctor` messages contain **only event_id, clinic_id and doctor_id**. No patient identifiers, booking identifiers, names, phones, reasons or medical data enter these public messages. Schedule/exception and appointment changes trigger slot invalidation; the Flutter adapter deduplicates and debounces events, refreshes on reconnect/resume and unsubscribes on scope change/disposal. A 15-second polling fallback keeps slots moving if WebSockets are unavailable. Hosted WebSocket delivery still requires live acceptance after migration.

## Performance changes and evidence

Navigation now prepares the relevant route code and first-page query on pointer intent/focus. Prefetch and mounted pages use identical clinic/role/doctor-aware keys. Catalog/settings reads remain fresh for 60 seconds, small selectors for 120 seconds, operational reads for 15 seconds. Availability has zero fresh-cache time and always reloads on mount. Successful mutations and private events invalidate scoped queries. A refresh button can explicitly refresh the active clinic data.

Pagination retains the previous rows only for another page of the same resource, clinic, role/doctor and filters, with an updating indicator. It never carries records between clinics or retains authorization failures. Cached data remains visible during background network errors with an error/retry notice. Catalog/status mutations no longer unnecessarily refetch the authorized clinic list; membership/settings writes still do.

Node shares only concurrent identical Auth/membership lookups. Settled successes and failures are immediately removed: later requests verify current authentication/membership again. There is no permission-result TTL cache or skipped SQL authorization.

A controlled Chrome comparison used the previous committed dashboard and the new version, identical 600 ms API latency, 800 ms pointer intent and a 31-second wall-clock jump. Click-to-doctor-rows measured **801 ms before / 73 ms after**. Pagination retained rows after the change; returning to the catalog triggered **1 request before / 0 after**. See [raw comparison](verification/performance.json). These figures describe that controlled navigation scenario, not a promise that uncached hosted requests complete in 73 ms. Real Supabase read probes varied from about 0.4 to 6.9 seconds; cold reads still depend on network/provider latency.

## Verification and activation

Local verification includes SQL/HTTP authorization and slot privacy, direct doctor saves, protected existing bookings, patient booking removing the slot, duplicate booking rejection, assigned-doctor events, mobile state/API/widget tests in RU/EN, and doctor/admin browser workflows. Flutter analyze is clean. `npm test` passed 81 backend and 27 dashboard tests. `flutter test` passed 50 tests; `flutter analyze` reports no issues. The TypeScript/Vite production build passed. Browser checks cover the existing administrator flows, direct doctor schedule saving, anonymous availability, patient booking/slot removal/conflict rejection, RU/EN, responsive layouts and logout/account switching.

Apply [migration 008](../supabase/migrations/202610160008_doctor_availability.sql) once in Supabase SQL Editor after migrations 001–007; do not rerun the initial setup. Restart the backend, refresh the dashboard and rebuild Flutter with its local configuration. For a project that already has 007, only this incremental SQL file is required. Live hosted OTP and Realtime remain unverified by local fixture tests.
