# Phase 3 catalog API

All paths use `/api/v1`. Public catalog requests use the active clinic UUID, never its display slug. Node reads Supabase through its server-only service role; mobile has no direct catalog database access. The OpenAPI 3.1 specification is [openapi.yaml](openapi.yaml).

| GET path | Result |
| --- | --- |
| `/clinics/:clinicId/home` | Clinic information plus at most 4 current promotions, 6 specialties, 3 featured doctors and 4 featured services |
| `/clinics/:clinicId/doctors` | Paginated active clinic assignments |
| `/clinics/:clinicId/doctors/:doctorId` | Clinic-specific professional details, clinic, paginated offered services and schedule overview |
| `/clinics/:clinicId/specialties` | Paginated active specialties with localized descriptions and active doctor counts |
| `/clinics/:clinicId/specialties/:specialtyId` | Specialty plus paginated related doctors and services |
| `/clinics/:clinicId/services` | Paginated active services with RUB prices, duration, category and clinic category choices |
| `/clinics/:clinicId/services/:serviceId` | Service, clinic and paginated doctors offering it |
| `/clinics/:clinicId/promotions` | Paginated active promotions within their start/end dates |
| `/clinics/:clinicId/booking-context` | Validated optional selections, clinic information and `online_booking_enabled: false` |
| `/me/notifications?clinic_id=:clinicId` | Latest 50 existing notifications for the verified bearer identity and selected clinic |

## Queries and pagination

The shared Zod query validator accepts `search` (trimmed, maximum 100 characters), optional UUID `specialtyId`, `serviceId`, `doctorId`, `category` (1–40 lowercase letters/underscores), `page` (1–1000, default 1), `limit` (1–100, default 12), `sort`, and `locale` (`ru` default, or `en`). Unknown query keys, invalid UUIDs, arrays and invalid bounds fail with 400 before catalog reads.

Doctor search matches localized names case-insensitively, with specialty and offered-service filters. Service search supports category, specialty and offering-doctor filters. Specialty search matches localized names. Percent, underscore and backslash search characters are escaped as literals. Promotion reads use date windows rather than name search. Filter parameters only affect the corresponding collection. Home and booking callers should send only the parameters documented for those operations.

`sort` accepts `featured`, `name`, `price_asc`, `price_desc`, or `experience_desc`. Featured uses configured `sort_order`, retaining the whole list; only home applies the featured flag. Name ordering uses the selected locale. Price ordering applies to services and doctor starting prices; experience ordering applies to doctors. Inapplicable sorting falls back to configured order. A UUID tie-breaker makes paging deterministic. Null doctor prices sort last.

```json
{
  "success": true,
  "data": {
    "items": [],
    "pagination": {"page": 1, "limit": 12, "total": 0, "hasMore": false}
  },
  "message": "Operation completed successfully"
}
```

The earlier doctors/specialties array payloads now return `data.items` and `data.pagination`. Flutter adapters were updated together. The dashboard only reads clinics and is unaffected. Service pages additionally return `categories`, independent of the current search/filter. Detail-related collections are bounded; their `page`/`limit` parameters paginate the nested collections. Mobile shows their first page and links to filtered catalogs for the remainder.

Localized business text returns `{ "ru": "…", "en": "…" }`; `locale` controls ordering, while Flutter chooses the displayed translation. Prices are exact RUB values for clinic services. Doctor starting prices are the minimum among active services offered in that clinic, or null. No availability indicator or appointment slot is calculated.

## Booking preparation

`GET /clinics/:clinicId/booking-context?doctorId=…&serviceId=…&specialtyId=…` is read-only. Any selections must exist in the active clinic. When provided together, doctor/service, service/specialty and doctor/specialty relationships are checked. Incompatible selections return 400; missing records return 404. Selecting from a doctor’s service list or a service’s doctor list preserves both IDs into preparation. No appointment creation, payment, slot reservation or confirmation exists in Phase 3.

Schedule rows contain weekday (`0` Sunday through `6` Saturday), local start/end times and stored breaks. They are a recurring overview in the clinic’s timezone, not current availability or a substitute for schedule exceptions and booking capacity.

## Errors and access

- 400: malformed UUID/query or incompatible selections.
- 401: missing/invalid session for personal notifications.
- 404: inactive/missing clinic or missing active catalog record in that clinic.
- 429: API rate limiting.
- 503: database/auth infrastructure unavailable.
- 500: unexpected or inconsistent tenant data; no catalog rows are returned.

Errors use `{success:false,error:{code,message,details:{requestId}}}`. Database messages and stack traces are not exposed. Empty successful results are distinct from errors. Every repository collection/detail/related-record read has a clinic predicate; the service checks returned row tenancy again. New catalog views use `security_invoker=true`, retain existing base-table RLS, revoke anon/authenticated access and grant only the server role. Personal notifications also constrain the verified user ID.
