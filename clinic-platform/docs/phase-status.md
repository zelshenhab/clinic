# Delivery status

## Phase 1

Implemented: monorepo workspaces, Android/iOS Flutter bootstrap, Russian/English ARB files, mobile network/failure groundwork, Cubit cancellation groundwork, React clinic catalog shell, Node configuration validation and error handling, health/public clinic endpoints, reusable authentication/RBAC helpers, shared contracts, SQL schema for all requested tables, composite tenant foreign keys, RLS and Realtime publication, overlapping-booking exclusion, deterministic repeatable catalog seeds, build and foundation tests, container API configuration.

Pending verification: migrations against a live Supabase instance; native Android/iOS binary builds. No hosted Supabase credentials were provided. Docker/PostgreSQL are unavailable on this host.

Demo patient profiles and appointments are intentionally deferred until the development auth seeder can create valid auth identities; no auth.users internals or real patient information are fabricated. Dashboard statistics will be derived from those records in Phase 5. Foundation tests do not claim to verify the later booking or realtime flows.

## Phase 2

Implemented: design system, complete RU/EN static localization and preference persistence, clinic selection/UUID restoration, domain cancellation and scoped state invalidation, go_router guards, real Supabase OTP adapter with secure storage/refresh/logout, profile completion APIs, four-tab shell and initial real catalog/personal appointment views. See [delivery](phase-2.md) and [files](phase-2-files.md).

Live SMS delivery/verification, migration execution and native device builds remain unverified. No fake OTP or session exists. This is not a production-verified authentication release.

## Phase 3

Implemented: API/database-backed clinic home, promotion carousel/list, searchable paginated doctor/specialty/service catalogs, clinic-specific professional details/services/prices, related-record navigation, scoped request cancellation/invalidation, cached images with original SVG placeholders, RU/EN localization, validated read-only booking preparation and guarded personal notification reads. Migration 003 adds catalog metadata, indexes and server-only catalog views; the revised seed targets 10/9 doctors, 8/7 specialties, 20/18 services and 4 promotions per clinic. See [delivery and limitations](phase-3.md), [source inventory](phase-3-files.md) and [API guide](catalog-api.md).

Verified locally: Flutter analysis and 43 tests; TypeScript/Vite builds; 27 backend and 1 dashboard tests. Supabase SDK/HTTP and mobile transport tests use controlled test-only responses. Live Supabase migrations/seeds/RLS, SMS and native/device behavior remain unverified. No production completeness or live end-to-end success is claimed.

## Phase 4 integration

Shared SQL availability, booking, rescheduling and cancellation now serve staff and patient API routes. The Flutter booking/confirmation screens and patient Realtime consumer remain pending; the existing mobile catalog and authentication phases are preserved.

## Phase 5

Implemented locally: RU/EN staff authentication, authorized clinic selection, overview and analytics, appointments, day/week/month calendar, doctors, specialties, services, promotions, patients, schedules, clinic settings, staff management and global booking settings. Backend membership checks, tenant SQL predicates, shared booking transactions, private Realtime audiences, uploads and audits accompany the interface. See [delivery and verification](phase-5.md).

Acceptance remains pending live Supabase Auth, invitations, Storage and private Realtime verification. Hosting and server configuration are explicitly deferred at the user's request. No deployment or production-completeness claim is made.
