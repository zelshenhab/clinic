# Phase 3 delivery — 2026-10-12

Phase 3 code is implemented in the existing Flutter/Node/Supabase architecture. Automated local checks passed. Live Supabase deployment, migration execution and real-device operation are still unverified; this is not a production-verified release.

## Features and screens

One clinic-driven home screen supplies a clinic logo/name/address header, switcher, guarded notification action, personalized/guest greeting, API promotion carousel, booking/doctors/services/appointments quick actions, popular specialties with counts, featured doctors, popular services and clinic contacts/hours. No business content or price is selected by a display slug in widgets.

Doctors, specialties and services have searchable catalogs, loading/error/empty states, functioning retries and pull-to-refresh. Doctors and services add filters and sorting; lists use server pagination and incremental loading. Doctor profiles show clinic membership title, experience, education, qualifications, biography, languages, clinic services/prices and recurring schedules. Specialty details show related doctors/services. Service details show clinic-specific duration/price, specialty, clinic and offering doctors. Related-record “See all” links open filtered catalogs. Promotions have a complete list screen. Personal notifications read existing user/clinic records; no demo notification creation or mark-as-read action was added.

Booking entry is a functional read-only selection validator and contact screen. Doctor/service context is preserved through relevant cards/detail navigation. It explicitly describes Phase 4 scheduling as unavailable; it never reports a successful appointment or fabricated slot. Availability, appointment creation, payments and booking confirmation remain Phase 4.

## Architecture and clinic isolation

Existing repositories/use cases and the single ApiClient were extended, rather than introducing a separate clinic implementation. Dedicated Home, Doctors, DoctorDetail, Specialties, SpecialtyDetail, Services, ServiceDetail and Promotions Cubits share typed catalog/resource state machinery. BookingEntry and Notifications use the same scope. API parsing and phone launch actions remain outside widgets.

Catalog lists debounce search by 350 ms, cancel earlier requests, reject responses by request version and clinic generation, deduplicate concurrent identical list reads, retain items on pagination failure and retry the same page. Refresh/filter changes restart the first page. Scope invalidation clears data immediately. Route providers observe the selected clinic UUID and are replaced on change, so back-stack screens cannot retain another clinic’s records. A shell transition wrapper that mounted the same Navigator twice was removed; router page transitions remain.

Backend controllers validate inputs and delegate to CatalogService and its Supabase repository. Reads validate the active clinic, constrain all queries and related collections to it, and reject inconsistent tenant rows. Responses use the existing envelopes and sanitized error strategy. Home overfetch is bounded; lists use lazy widgets; images use cached_network_image. There is no catalog record cache to become stale. Image caching stores resources by URL and does not select business data.

## Database migration and demo seed

Added [202610120003_medical_catalog.sql](../supabase/migrations/202610120003_medical_catalog.sql), retaining the first two migrations. It adds optional clinic logos; clinic membership professional metadata, experience/language overrides and featured order; localized specialty descriptions/icons/active order; service categories/active/featured order; and promotion actions/active order. It adds tenant/filter and trigram name indexes and server-only, security-invoker catalog views. Existing composite clinic foreign keys and base-table RLS remain authoritative.

The existing specialty table already represents clinic-associated records, so it was extended without adding a duplicate shared taxonomy. Service records/prices stay clinic-associated; global doctors can have different assignments, services and schedules across clinics. Catalog views derive prices and relationships from those assignments. Tests include one shared doctor identity with different clinic prices.

The updated [catalog.sql](../supabase/seeds/catalog.sql) uses deterministic UUIDs and conflict clauses. The intended active seed counts are:

| Clinic | Doctors | Specialties | Services | Promotions |
| --- | ---: | ---: | ---: | ---: |
| Millennium Medical Center | 10 | 8 | 20 | 4 |
| Nova Health Clinic | 9 | 7 | 18 | 4 |

Names, addresses, phone numbers and qualifications are fictional. Descriptions are Russian/English; prices vary by clinic/service; consultations and diagnostics have stored durations. Demo clinic hours are weekdays 09:00–18:00 and Saturday 10:00–15:00; recurring doctor schedules store a 13:00–14:00 break. Promotions run from 2026-01-01 to 2028-01-01, and disappear after expiry. Original SVG doctor/banner illustrations provide approved placeholders, with optional database image URLs supported. No real portrait, patient, OTP or authenticated demo identity was added.

Unused old demo services/promotions/assignments are marked inactive. Obsolete doctor-service links are removed only when no appointment references them. Seed repeats avoid duplicates; existing referenced appointment relations are preserved. This seed updates demonstration records and should be applied to a development database. Counts were inspected from the SQL fixture; actual database seed execution/idempotence remains unverified here.

Apply migration 003 after 001/002, then the revised seed through Supabase CLI or the project’s database tooling. For an empty local Supabase environment, `supabase db reset` applies all migrations and seeds but deletes local database contents. Start the Node API with server-only credentials, configure Flutter’s API URL, then run the existing mobile entry point. See [mobile setup](../apps/mobile/README.md).

## Endpoints and source inventory

Implemented/extended the eight requested clinic home/catalog endpoints, plus read-only `/clinics/:clinicId/booking-context` and authenticated `/me/notifications`. Doctors/specialties lists now return paginated collections. See [catalog API guide](catalog-api.md), [OpenAPI](openapi.yaml) and the complete [file inventory](phase-3-files.md).

## Localization and presentation

Russian remains the default; English persists through the existing preference flow. New ARB keys cover catalog navigation/search/filters, profile fields, section labels, duration/count/experience parameters, price labels, schedule disclaimer, booking preparation, image semantics and contacts. Database translations supply business text; Intl formats RUB prices and weekday labels. No widget embeds fictional catalog records.

Shared rounded cards, themed buttons, skeletons, lazy catalog lists, image fallbacks, detail layouts and carousel transitions reuse the existing blue/white design system. Long button labels wrap. Navigation/layout tests cover both languages at 320 × 640 with 130% text scale, including scrolling through catalog screens. Native font/platform behavior still needs device review.

## Executed verification

- `flutter analyze`: no issues.
- `flutter test`: 43 tests passed, including existing Phase 2 regressions and new catalog repository, Cubit, widget and navigation coverage.
- `npm run build`: TypeScript API and Vite dashboard passed.
- `npm test`: 27 backend tests and 1 dashboard test passed.

Tests cover both clinic predicates, SDK/PostgREST query construction, search and relationship filters, clinic-specific prices, profile parsing, bounded home responses, pagination, invalid UUID/query handling, stale search/append responses, reset, deduplication, network error/retry, booking compatibility and RU/EN navigation/layout. Backend integration tests exercise Express, Zod, services, repository and the actual Supabase SDK against controlled HTTP responses. Flutter repository/widget tests use controlled Dio transport and test-only fixtures. These are not live database or device tests, and test fixture responses are never used in application runtime.

## Remaining limitations

No Supabase credentials, Docker/PostgreSQL service or Supabase CLI were available for live migrations, seed repeats, RLS execution or end-to-end mobile-to-database testing. Live SMS, native Android/iOS binary builds, physical-device image caching/keychain/telephone launch, database query plans and load testing remain unverified. Screens display localized errors until the real API/database are configured. Booking, push delivery, realtime clients and staff management remain later phases. Demo illustrations remain placeholders for licensed clinic branding/portraits. There is no production deployment in this phase.
