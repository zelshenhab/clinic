# Verification — Phase 3, 2026-10-12

- `flutter analyze`: no issues.
- `flutter test`: 43 passed; new catalog API mapping, price/tenant validation, pagination/retry, search cancellation, deduplication, clinic reset, RU/EN navigation at 320px/130% text scale, home retry, plus Phase 2 regressions.
- `npm run build`: TypeScript API and Vite dashboard passed.
- `npm test`: 27 backend and 1 dashboard tests passed. Catalog integration exercises Express/Zod/service/repository/Supabase SDK with controlled PostgREST HTTP transport.

The fixtures are test-only. No application mock-success or offline business-data fallback exists. SQL seed counts were inspected (10/9 doctors, 8/7 specialties, 20/18 services, 4 promotions each), but migrations and repeated seed execution were not performed against a database.

Not executed: live Supabase migrations/seeds/RLS, SMS delivery, native binary/device checks, phone launch/image-cache/keychain plugin behavior, query-plan/load tests, booking concurrency or realtime clients. No Docker/PostgreSQL/Supabase CLI or hosted credentials were supplied. See [Phase 3 delivery](phase-3.md) for scope and setup.

---

# Verification — Phase 2, 2026-10-12

- `flutter analyze`: no issues.
- `flutter test`: 27 tests passed, covering ClinicCubit/restoration/rapid switching, scoped late responses and reset, auth state/expiry/resend/logout, stream errors, Supabase SDK request/refresh behavior with mock HTTP, secure-storage adapter, international phone validation, route guards, repository response validation, single-retry token refresh, clinic-selection widgets and persisted localization.
- `npm run build`: TypeScript API and Vite dashboard builds passed.
- `npm test`: 8 backend tests and 1 dashboard test passed.

API HTTP tests require permission to bind an ephemeral local socket. Widget async stream cleanup runs outside the test’s fake clock. Supabase adapter tests use controlled HTTP responses and do not test live SMS.

Not executed: live database migrations/seeds/RLS integration, SMS delivery/verification, native Android/iOS binaries, real-device secure-storage behavior, booking concurrency or realtime clients. No Docker/PostgreSQL service or Supabase credentials were supplied. Booking and realtime client implementation belong to later phases.

### Patient experience extension

See [patient experience verification and activation](patient-experience.md). New browser scenario: `PLAYWRIGHT_MODULE=/path/to/playwright-core node apps/dashboard/tests/patient-experience-browser.mjs` against the isolated test API/Vite servers. It checks policy writes/public policy reads, confirmed appointment arrival/waiting, own-doctor queue, copy-week/day-off mutations and public nearest-time search. It uses test-only authentication and local SQL, and does not certify hosted Supabase sessions or WebSockets.

Final extension checks: 95 backend + 32 dashboard + 59 Flutter tests passed; Flutter analyze is clean; production builds pass. Administrator, doctor and new patient-experience browser scenarios passed against isolated local fixtures.
