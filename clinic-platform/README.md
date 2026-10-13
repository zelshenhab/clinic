# Multi-clinic platform

Phase 1–3 mobile foundation and Phase 5 administration implementation for one Flutter application, a React staff dashboard, and an Express API backed by Supabase. This repository is not yet a production booking product. See [phase status](docs/phase-status.md).

## Run locally

Prerequisites: Node 22+, Flutter 3.41+/Dart 3.11+, Supabase CLI and Docker for a local database.

1. `npm ci`
2. `cp .env.example .env` and replace Supabase keys with the local values from `supabase status`.
3. `supabase start` then `supabase db reset` (local reset deletes local data).
4. `npm run dev:api`
5. Copy `apps/dashboard/.env.example` to `apps/dashboard/.env`, provide the API URL and public Supabase configuration, then run `npm run dev:dashboard`.
6. Configure `apps/mobile/config/local.json` as described in [mobile setup](apps/mobile/README.md), then run Flutter with `--dart-define-from-file=config/local.json`.

The dashboard provides authenticated, clinic-scoped staff administration. Without the API/database it displays a retryable error, never fabricated successful data. Flutter now provides clinic selection, public catalog browsing, a four-tab shell, persisted localization, and Supabase phone-authentication integration. Live OTP delivery and verification still require external setup and have not been tested.

`npm run build` and `npm test` verify the JavaScript/TypeScript workspaces. Run `flutter analyze` and `flutter test` inside `apps/mobile`. UUID clinic keys are separate from the `clinic_001` / `clinic_002` slugs. All demo catalog values are fictional.

Never put the service role key in a client environment. Client builds receive only Supabase URL and public anon/publishable key. `.env` is ignored. Dependency versions and lockfiles are resolved and recorded for reproducible installation.

See [architecture](docs/architecture.md), [security](docs/security.md), and [API specification](docs/openapi.yaml).

[Phase 2 delivery and limitations](docs/phase-2.md) · [File inventory](docs/phase-2-files.md)

[Phase 3 delivery and limitations](docs/phase-3.md) · [Catalog API guide](docs/catalog-api.md) · [Phase 3 file inventory](docs/phase-3-files.md)

[Phase 5 delivery and local verification](docs/phase-5.md). Hosting and server setup are deferred in the current scope.

[Phase 5 doctor workspace](docs/phase-5-doctor.md): private doctor appointments, patients, calendar, requests and administrator approval. Apply incremental migration 007 after the existing schema before using these routes.
