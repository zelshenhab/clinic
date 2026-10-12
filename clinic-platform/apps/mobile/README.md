# Flutter clinic application

Russian-first mobile application with clinic selection, public browsing, guarded personal routes, and real Supabase phone authentication integration.

## Configuration

Copy `config/local.example.json` to ignored `config/local.json`. Set `API_URL` to a reachable Node API ending in `/api/v1`. Android emulator uses `http://10.0.2.2:3000/api/v1`; physical devices need a reachable host, and iOS Simulator uses `http://127.0.0.1:3000/api/v1`. Physical iOS devices need a reachable development endpoint. Release endpoints must use HTTPS.

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (or the Supabase publishable key in that field). These are client-safe public credentials. Never use a service role key. Set `SMS_ENABLED` true only after configuring Phone Auth and an SMS provider in Supabase.

```sh
flutter pub get
flutter run --dart-define-from-file=config/local.json
```

Without SMS configuration, debug builds expose a labeled guest browsing flow. No local OTP verifier, hardcoded code, or authenticated development identity is provided. Release builds show localized sign-in unavailability, with public browsing still available.

The Supabase SDK handles session recovery, lifecycle refresh, and real SMS OTP verification. Its session serialization is stored through `flutter_secure_storage`; clinic/language preferences alone use SharedPreferences. iOS keychain entitlements are included; device signing/provisioning remains external configuration. Phone OTP does not require magic-link/deep-link configuration.

Run `flutter analyze` and `flutter test`. Adapter tests use controlled HTTP transports and do not prove live SMS delivery.

Phase 3 adds clinic home/promotions, searchable and paginated doctor/specialty/service catalogs, professional detail screens, RUB prices, notifications read access, and validated booking preparation. Apply all three SQL migrations and the updated seed before starting the API. The production app has no mock catalog fallback. Missing API/database access produces localized retryable errors. Doctor and banner assets are original SVG placeholders; optional API image URLs use a disk-backed cache. Image caching does not cache catalog records.

See [Phase 3 report](../../docs/phase-3.md) for the complete scope and verification limits. Booking slots and appointment creation remain Phase 4.
