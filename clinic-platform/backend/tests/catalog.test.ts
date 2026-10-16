import { beforeEach, expect, it } from "vitest";
import request from "supertest";
import { createClient } from "@supabase/supabase-js";
import { createApp } from "../src/app.js";
import { catalogRoutes } from "../src/modules/doctors/routes.js";
import { clinicRepository } from "../src/modules/clinics/repository.js";
const a = "12a30244-3000-4000-8000-000000000001",
  b = "12a30244-3000-4000-8000-000000000002";
const d = "12a30244-3000-4000-8000-000000000003",
  sp = "12a30244-3000-4000-8000-000000000004",
  svc = "12a30244-3000-4000-8000-000000000005";
const text = (ru: string, en = ru) => ({ ru, en });
const clinics = [a, b].map((id) => ({
  id,
  active: true,
  name: text(id),
  address: text("Address"),
  description: text("Description"),
  timezone: "Europe/Moscow",
}));
const doctors = [a, b].flatMap((clinic_id, i) =>
  Array.from({ length: 3 }, (_, j) => ({
    id: j === 0 ? d : `12a30244-3000-4000-8000-0000000000${10 + i * 3 + j}`,
    clinic_id,
    name: text(j === 0 ? "Анна" : "Борис", j === 0 ? "Anna" : "Boris"),
    search_text: j === 0 ? "Анна Anna" : "Борис Boris",
    name_ru: j === 0 ? "Анна" : "Борис",
    name_en: j === 0 ? "Anna" : "Boris",
    specialty_ids: j === 0 ? [sp] : [],
    service_ids: j === 0 ? [svc] : [],
    specialties: j === 0 ? [{ id: sp, name: text("Терапия", "Therapy") }] : [],
    starting_price_rub: i === 0 ? 2200 : 3100,
    featured: true,
    sort_order: j,
    education: text("University"),
    biography: text("Bio"),
    qualifications: text("Qualification"),
    languages: ["ru"],
    experience_years: 12,
  })),
);
const services = [a, b].map((clinic_id, i) => ({
  id: svc,
  clinic_id,
  specialty_id: sp,
  name: text("Консультация", "Consultation"),
  search_text: "Консультация Consultation",
  price_rub: i === 0 ? 2200 : 3100,
  duration_minutes: 30,
  category_key: "consultations",
  category: text("Консультации", "Consultations"),
  doctor_ids: [d],
  featured: true,
  sort_order: 0,
}));
const specialties = [a, b].map((clinic_id) => ({
  id: sp,
  clinic_id,
  name: text("Терапия", "Therapy"),
  search_text: "Терапия Therapy",
  sort_order: 0,
}));
const config = {
  NODE_ENV: "test" as const,
  PORT: 3000,
  CORS_ORIGINS: "http://localhost:5173",
  SUPABASE_URL: "https://db.example.test",
  SUPABASE_ANON_KEY: "test",
  SUPABASE_SERVICE_ROLE_KEY: "test",
};
let calls: URL[],
  fail = false,
  leak = false;
function build() {
  const fetch: typeof globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    calls.push(url);
    const table = url.pathname.split("/").pop()!;
    if (fail)
      return new Response(
        JSON.stringify({ message: "secret internal SQL", code: "XX000" }),
        { status: 500 },
      );
    let rows: Record<string, any>[] =
      (
        {
          clinics,
          catalog_doctors: doctors,
          catalog_services: services,
          catalog_specialties: specialties,
          catalog_categories: services.map(
            ({ clinic_id, category_key, category }) => ({
              clinic_id,
              category_key,
              category,
            }),
          ),
          doctor_schedules: [a, b].map((clinic_id) => ({
            clinic_id,
            doctor_id: d,
            weekday: 1,
            starts_at: "09:00:00",
            ends_at: "18:00:00",
            breaks: [],
          })),
          promotions: [a, b].map((clinic_id) => ({
            id: d,
            clinic_id,
            active: true,
            starts_at: "2026-01-01T00:00:00Z",
            ends_at: "2028-01-01T00:00:00Z",
            sort_order: 0,
            title: text("Checkup"),
          })),
        } as Record<string, Record<string, any>[]>
      )[table] ?? [];
    for (const [key, value] of url.searchParams) {
      if (value.startsWith("eq."))
        rows = rows.filter((r) => String(r[key]) === value.slice(3));
      if (value.startsWith("cs.")) {
        const ids = value.slice(4, -1).split(",");
        rows = rows.filter((r) => ids.every((id) => r[key]?.includes(id)));
      }
      if (value.startsWith("ilike.")) {
        const search = value.slice(7, -1).toLowerCase();
        rows = rows.filter((r) => r[key]?.toLowerCase().includes(search));
      }
      if (value.startsWith("lte."))
        rows = rows.filter((r) => r[key] <= value.slice(4));
      if (value.startsWith("gt."))
        rows = rows.filter((r) => r[key] > value.slice(3));
    }
    const total = rows.length,
      offset = Number(url.searchParams.get("offset") ?? 0),
      limit = Number(url.searchParams.get("limit") ?? total);
    rows = rows.slice(offset, offset + limit);
    if (leak && table === "catalog_doctors")
      rows = [{ ...doctors[0], clinic_id: b }];
    return new Response(JSON.stringify(rows), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Content-Range": `${offset}-${offset + rows.length - 1}/${total}`,
      },
    });
  };
  const db = createClient(config.SUPABASE_URL, "test-service-role", {
    global: { fetch },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return createApp(config, clinicRepository(db), undefined, catalogRoutes(db));
}
beforeEach(() => {
  calls = [];
  fail = false;
  leak = false;
});
it.each([a, b])("scopes every SDK/PostgREST read to clinic %s", async (id) => {
  const r = await request(build()).get(`/api/v1/clinics/${id}/doctors`);
  expect(r.status).toBe(200);
  expect(r.body.data.items).toHaveLength(3);
  expect(r.body.data.items.every((row: any) => row.clinic_id === id)).toBe(
    true,
  );
  expect(
    calls.every(
      (u) =>
        u.searchParams.get(
          u.pathname.endsWith("/clinics") ? "id" : "clinic_id",
        ) === `eq.${id}`,
    ),
  ).toBe(true);
});
it("supports name search, specialty and service filtering through the repository", async () => {
  const app = build();
  for (const query of [
    { search: "Anna" },
    { specialtyId: sp },
    { serviceId: svc },
  ]) {
    const r = await request(app)
      .get(`/api/v1/clinics/${a}/doctors`)
      .query(query);
    expect(r.status).toBe(200);
    expect(r.body.data.items.map((x: any) => x.id)).toEqual([d]);
  }
  expect(
    calls.some((u) => u.searchParams.get("search_text") === "ilike.%Anna%"),
  ).toBe(true);
  expect(
    calls.some((u) => u.searchParams.get("specialty_ids") === `cs.{${sp}}`),
  ).toBe(true);
});
it("uses bounded pagination, deterministic sorting and localized ordering", async () => {
  const app = build();
  const r = await request(app)
    .get(`/api/v1/clinics/${a}/doctors`)
    .query({ page: 2, limit: 2, sort: "name", locale: "en" });
  expect(r.body.data.pagination).toEqual({
    page: 2,
    limit: 2,
    total: 3,
    hasMore: false,
  });
  expect(r.body.data.items).toHaveLength(1);
  const u = calls.at(-1)!;
  expect(u.searchParams.get("offset")).toBe("2");
  expect(u.searchParams.get("limit")).toBe("2");
  expect(u.searchParams.get("order")).toBe("name_en.asc,id.asc");
});
it("returns different service prices for the same doctor and service in each clinic", async () => {
  const app = build();
  for (const [id, price] of [
    [a, 2200],
    [b, 3100],
  ] as const) {
    const r = await request(app).get(`/api/v1/clinics/${id}/services/${svc}`);
    expect(r.status).toBe(200);
    expect(r.body.data.price_rub).toBe(price);
    expect(r.body.data.doctors.items[0].clinic_id).toBe(id);
  }
});
it("loads clinic membership professional details, services and schedules", async () => {
  const r = await request(build()).get(`/api/v1/clinics/${b}/doctors/${d}`);
  expect(r.status).toBe(200);
  expect(r.body.data.clinic.id).toBe(b);
  expect(r.body.data.education.ru).toBe("University");
  expect(r.body.data.services.items[0].price_rub).toBe(3100);
  expect(r.body.data.schedules).toHaveLength(1);
});
it("loads related specialty records and category/doctor-filtered services", async () => {
  const app = build();
  const r = await request(app).get(`/api/v1/clinics/${a}/specialties/${sp}`);
  expect(r.status).toBe(200);
  expect(r.body.data.doctors.items).toHaveLength(1);
  expect(r.body.data.services.items).toHaveLength(1);
  const filtered = await request(app)
    .get(`/api/v1/clinics/${a}/services`)
    .query({ doctorId: d, category: "consultations" });
  expect(filtered.body.data.categories[0].category_key).toBe("consultations");
  expect(filtered.body.data.items).toHaveLength(1);
});
it("bounds home sections and retrieves active promotion data", async () => {
  const r = await request(build()).get(`/api/v1/clinics/${b}/home`);
  expect(r.status).toBe(200);
  expect(r.body.data.clinic.id).toBe(b);
  expect(r.body.data.promotions).toHaveLength(1);
  for (const u of calls.filter(
    (u) =>
      !u.pathname.endsWith("/clinics") &&
      !u.pathname.endsWith("/catalog_categories"),
  ))
    expect(Number(u.searchParams.get("limit"))).toBeLessThanOrEqual(6);
});
it.each([
  { clinic: "clinic_001", q: {} },
  { clinic: a, q: { page: 0 } },
  { clinic: a, q: { limit: 101 } },
  { clinic: a, q: { specialtyId: "invalid" } },
  { clinic: a, q: { sort: "unsafe" } },
  { clinic: a, q: { unknown: "secret" } },
])(
  "rejects invalid catalog input before database reads: %j",
  async ({ clinic, q }) => {
    const r = await request(build())
      .get(`/api/v1/clinics/${clinic}/doctors`)
      .query(q);
    expect(r.status).toBe(400);
    expect(calls).toHaveLength(0);
  },
);
it("returns safe 404s for unknown clinic and doctor records", async () => {
  const app = build(),
    missing = "12a30244-3000-4000-8000-000000000099";
  for (const path of [
    `${missing}/home`,
    `${a}/doctors/${missing}`,
    `${a}/services/${missing}`,
    `${a}/specialties/${missing}`,
  ]) {
    const r = await request(app).get(`/api/v1/clinics/${path}`);
    expect(r.status).toBe(404);
  }
});
it("does not turn database failures into successful empty pages, and recovers on retry", async () => {
  const app = build();
  fail = true;
  const r = await request(app).get(`/api/v1/clinics/${a}/doctors`);
  expect(r.status).toBe(503);
  expect(JSON.stringify(r.body)).not.toContain("secret");
  fail = false;
  expect((await request(app).get(`/api/v1/clinics/${a}/doctors`)).status).toBe(
    200,
  );
});
it("rejects a repository response that crosses clinic boundaries", async () => {
  leak = true;
  const r = await request(build()).get(`/api/v1/clinics/${a}/doctors`);
  expect(r.status).toBe(500);
  expect(r.body.success).toBe(false);
  expect(r.body.data).toBeUndefined();
});
it("validates booking preparation relations and never confirms an appointment", async () => {
  const app = build();
  const good = await request(app)
    .get(`/api/v1/clinics/${a}/booking-context`)
    .query({ doctorId: d, serviceId: svc, specialtyId: sp });
  expect(good.status).toBe(200);
  expect(good.body.data.online_booking_enabled).toBe(true);
  const wrong = await request(app)
    .get(`/api/v1/clinics/${a}/booking-context`)
    .query({ doctorId: doctors[1].id, serviceId: svc });
  expect(wrong.status).toBe(400);
  expect(
    calls.every((u) => u.pathname.split("/").pop() !== "appointments"),
  ).toBe(true);
});
