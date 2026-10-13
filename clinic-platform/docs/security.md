# Access controls and verification scope

Hosting, server configuration and jurisdiction decisions are deferred at the user's request. This document describes implemented application controls and does not claim production compliance or live provider verification.

Clients receive only a Supabase URL and public anon/publishable key. Service credentials remain in Node. Every admin request verifies the JWT through Supabase getUser and loads active staff memberships from the database; roles or clinic IDs supplied by the browser never grant access. SUPER_ADMIN manages cross-clinic configuration and staff. CLINIC_ADMIN manages the assigned clinic. RECEPTIONIST handles appointments and patients. DOCTOR reads their own appointments/schedules and records permitted completion/no-show transitions.

SQL functions repeat membership and tenant checks, use bounded lists and composite clinic foreign keys, and are denied to anon/authenticated clients unless explicitly required for a narrow Realtime authorization helper. RLS defaults to deny. Medical records remain unavailable through these routes. Linking an existing patient exclusively attached to another clinic requires SUPER_ADMIN authorization.

Booking mutations derive patient identity on patient routes, verify schedules and service assignments, store price snapshots and audit changes atomically. Expected update timestamps reject stale edits. Global doctor overlap exclusion prevents overlapping active bookings across clinics. Schedule edits reject conflicts with future booked appointments instead of silently moving them.

Private Realtime messages contain identifiers rather than patient details. Recipients are computed from current active memberships at commit time, preventing revoked users receiving new events. Clients fetch authorized details through Node and remove channels on clinic switch/logout. Live provider behavior still needs later verification.

Catalog uploads accept bounded JPEG/PNG/WebP files, decode and re-encode with Sharp, strip metadata and write clinic-specific random paths. The public bucket is for catalog artwork only. Failed audit writes remove uploaded artifacts. Mutation audit history is exposed read-only; application routes do not permit deleting it.

Failures expose stable codes, safe field details and request IDs. Logs exclude tokens, request bodies, phone numbers and raw database errors. Test-only authentication adapters are confined to tests/support and are guarded by NODE_ENV=test; production imports no bypass.

Local SQL, HTTP, binary upload and UI tests provide evidence for these controls. Live Auth/email delivery, Storage, Realtime, multi-client load behavior and operational controls have not been certified by those tests.

Doctor extension controls: doctor_id is derived from verified active account/clinic assignments and is rejected in doctor query/body schemas. Own SQL predicates protect all appointments, patient relationships, calendar events and statistics, including dual-role accounts. Patient lists omit contact information; the patient's phone is permitted only in operational own-appointment details. Medical records and clinical notes remain unavailable.

New change-request tables use default-deny RLS with no browser-role grants; privileged RPCs are service-only. Doctor requests cannot immediately change availability. Only authorized administrators review, and requesters cannot approve themselves. Approval revalidates current doctor access, schedule baselines, booking versions and conflicts atomically. Private request events contain identifiers only and target current authorized recipients. Active account linking validates clinic assignment and consistent doctor identity across clinics.
