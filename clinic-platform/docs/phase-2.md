# Phase 2 delivery

## Screens

Splash with restoration; clinic selection with original clinic illustration or configured image URL, localized name/address/description and selection; phone entry with editable international prefix and Russian number normalization; OTP verification and resend countdown; profile completion; shared shell with Home/Doctors/Appointments/Profile tabs; specialties; profile; persisted-language settings. Public browsing remains available without sign-in; appointments require an authenticated, completed profile.

Home displays real selected-clinic information, contact/working hours, doctors and specialty navigation. Doctors/specialties read actual catalog endpoints. Appointments display actual user-owned records in the clinic timezone, or an empty/error state. Booking controls are not exposed until Phase 4.

## API integration

Mobile uses `GET /api/v1/clinics`, `GET /api/v1/clinics/:clinicId/doctors`, `GET /api/v1/clinics/:clinicId/specialties`, `GET /api/v1/me/profile`, `PATCH /api/v1/me/profile`, and `GET /api/v1/me/appointments?clinic_id=<uuid>`.

Backend also supplies `POST /api/v1/auth/verify-session`, `GET /api/v1/auth/me`, and `POST /api/v1/auth/logout`. The mobile auth adapter calls Supabase directly for SMS authentication, session validation/refresh, and logout; the API independently validates JWTs for private operations. The verified identity is the only profile/appointment owner identifier accepted. Profile writes reject additional fields. Catalog queries filter clinic UUID and active status; appointment reads filter both authenticated patient and selected clinic.

## Authentication status

Implemented real Supabase signInWithOtp/verifyOTP integration, secure session storage, startup validation, serialized refresh, single-retry Dio authorization, typed errors, resend throttling, profile completion, logout, and expired-session state clearing. Automatic SDK refresh-stream errors are handled.

**Live OTP delivery and verification have not been tested.** No Supabase project credentials or SMS provider were supplied. Mock HTTP adapter tests prove request/mapping behavior and shared refresh operations only. No successful session is fabricated when SMS is disabled.

## Required external setup

Apply `202610120002_mobile_foundation.sql` after the original migration and run the repeatable catalog seed for fresh local instances. Existing hosted projects should apply incremental migrations without resetting data. Configure backend `.env`; client `config/local.json`; Supabase Phone Auth/SMS provider, expiry and rate limits; reachable HTTPS URLs; and iOS provisioning/keychain capabilities. See the mobile README.

Database execution, real-device keychain operation, native binaries, and end-to-end SMS remain unverified on this host. Authentication is not represented as production-verified.

## Isolation and architecture

ClinicCubit owns the selected clinic and persists only its database UUID. It validates restored selection against active API records. ClinicScope cancels domain cancellation signals, increments a generation, and clears registered feature state. Data adapters translate cancellation to Dio CancelToken; domain repositories/use cases do not import Dio. Old responses cannot repopulate a new clinic. Switching clears selection before persistence, prevents stale navigation, and constructs a new shell without animating old-clinic content. Private state also clears on logout/expired identity.

Repositories and use cases drive Cubits; widgets call Cubits and render state. GetIt composes dependencies. Generated ARB localization covers static UI labels, errors, empty states, navigation and controls. Clinic content is localized database data; the Russian locale defaults and both selected locale and clinic are persisted. The structured diagnostics logger records event/code only, excluding exception text and sensitive content.

## Phase 3 next

Expand home with database-backed promotions and featured/popular catalog sections; doctor details/search/specialty filters; specialty detail relationships; services catalog/search/prices and doctor assignments. Add the necessary validated catalog contracts and endpoints, preserve scope cancellation/guards, and test each flow. Availability and booking remain Phase 4; realtime client subscriptions remain Phase 6.
