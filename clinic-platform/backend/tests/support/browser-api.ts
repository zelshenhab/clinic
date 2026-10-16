import { bookingRoutes } from "../../src/modules/appointments/routes.js";
import { doctorRoutes } from "../../src/modules/doctor/routes.js";
// Isolated browser QA only. Never imported by the production server.
import { PGlite } from "@electric-sql/pglite";
import { btree_gist } from "@electric-sql/pglite/contrib/btree_gist";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createApp } from "../../src/app.js";
import { adminRoutes } from "../../src/modules/admin/routes.js";
if (process.env.NODE_ENV !== "test")
  throw Error("This fixture server requires NODE_ENV=test");
const db = new PGlite({ extensions: { btree_gist, pg_trgm } }),
  root = fileURLToPath(new URL("../../../supabase/", import.meta.url));
await db.exec(
  `create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema extensions;create schema realtime;create schema storage;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;create publication supabase_realtime;create table realtime.messages(id uuid default gen_random_uuid(),topic text,extension text,payload jsonb);alter table realtime.messages enable row level security;grant select on realtime.messages to authenticated;create function realtime.topic() returns text language sql as $$select current_setting('realtime.topic',true)$$;create function realtime.send(payload jsonb,event text,topic text,private boolean) returns void language sql as $$insert into realtime.messages(topic,extension,payload) values(topic,'broadcast',payload)$$;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);`,
);
for (const f of readdirSync(root + "migrations").sort())
  await db.exec(readFileSync(root + "migrations/" + f, "utf8"));
await db.exec(readFileSync(root + "seeds/catalog.sql", "utf8"));
const actor = "10000000-0000-4000-8000-000000000001",
  patient = "10000000-0000-4000-8000-000000000002";
const token =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
  Buffer.from(
    JSON.stringify({ sub: actor, role: "authenticated", exp: 4102444800 }),
  ).toString("base64url") +
  ".testsignature";
await db.query("insert into auth.users(id) values($1),($2)", [actor, patient]);
await db.query(
  "insert into public.staff_memberships(user_id,role) values($1,'SUPER_ADMIN')",
  [actor],
);
for (const { id: clinic } of (
  await db.query<any>("select id from public.clinics")
).rows) {
  await db.query("select public.admin_patient_link($1,$2,$3,$4)", [
    actor,
    clinic,
    patient,
    JSON.stringify({
      full_name: "QA Patient",
      email: "patient@example.invalid",
      phone: "+70000000000",
    }),
  ]);
  const option = (
    await db.query<any>("select public.admin_options($1,$2) as o", [
      actor,
      clinic,
    ])
  ).rows[0].o;
  const doctor = option.doctors[0].id,
    service = option.services.find((s: any) =>
      s.doctor_ids.includes(doctor),
    ).id;
  for (let offset = 0; offset < 7; offset++) {
    const day = (
      await db.query<any>(
        "select to_char(current_date+$1::integer,'YYYY-MM-DD') as d",
        [offset],
      )
    ).rows[0].d;
    const slots = (
      await db.query<any>(
        "select public.admin_availability($1,$2,$3,$4,$5) as s",
        [actor, clinic, doctor, service, day],
      )
    ).rows[0].s;
    if (slots.length) {
      await db.query("select public.admin_book($1,$2,$3)", [
        actor,
        clinic,
        JSON.stringify({
          patient_id: patient,
          doctor_id: doctor,
          service_id: service,
          starts_at: slots[0].starts_at,
        }),
      ]);
      break;
    }
  }
}
const doctorActor = "10000000-0000-4000-8000-000000000003";
const doctorToken =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
  Buffer.from(
    JSON.stringify({
      sub: doctorActor,
      role: "authenticated",
      exp: 4102444800,
    }),
  ).toString("base64url") +
  ".testsignature";
await db.query("insert into auth.users(id) values($1)", [doctorActor]);
const assigned = (
  await db.query<any>(
    "select doctor_id from public.doctor_clinics order by clinic_id,sort_order limit 1",
  )
).rows[0].doctor_id;
await db.query(
  "insert into public.doctor_clinics(clinic_id,doctor_id) select id,$1 from public.clinics on conflict(clinic_id,doctor_id) do nothing",
  [assigned],
);
await db.query(
  "insert into public.staff_memberships(user_id,clinic_id,role,doctor_id) select $1,clinic_id,'DOCTOR',doctor_id from public.doctor_clinics where doctor_id=$2",
  [doctorActor, assigned],
);
// An actual future booking for the doctor test account.
const dc = (
  await db.query<any>(
    "select clinic_id from public.doctor_clinics where doctor_id=$1 order by clinic_id limit 1",
    [assigned],
  )
).rows[0].clinic_id;
const svc = (
  await db.query<any>(
    "select service_id from public.doctor_services where clinic_id=$1 and doctor_id=$2 and active limit 1",
    [dc, assigned],
  )
).rows[0].service_id;
for (let offset = 1; offset < 8; offset++) {
  const day = (
    await db.query<any>("select (current_date+$1::integer)::text as day", [
      offset,
    ])
  ).rows[0].day;
  const slots = (
    await db.query<any>(
      "select public.admin_availability($1,$2,$3,$4,$5) slots",
      [actor, dc, assigned, svc, day],
    )
  ).rows[0].slots;
  if (slots.length) {
    await db.query("select public.admin_book($1,$2,$3)", [
      actor,
      dc,
      JSON.stringify({
        patient_id: patient,
        doctor_id: assigned,
        service_id: svc,
        starts_at: slots[0].starts_at,
      }),
    ]);
    break;
  }
}
const patientToken =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
  Buffer.from(
    JSON.stringify({ sub: patient, role: "authenticated", exp: 4102444800 }),
  ).toString("base64url") +
  ".testsignature";
const fake = {
  auth: {
    getUser: async (value: string) => ({
      data: {
        user:
          value === token
            ? { id: actor, email: "qa@example.invalid" }
            : value === doctorToken
              ? { id: doctorActor, email: "doctor@example.invalid" }
              : value === patientToken
                ? { id: patient, email: "patient@example.invalid" }
                : null,
      },
      error: [token, doctorToken, patientToken].includes(value)
        ? null
        : { status: 401 },
    }),
  },
  rpc: async (name: string, args: Record<string, unknown>) => {
    try {
      if (!/^(admin|doctor|patient)_[a-z_]+$|^(public_availability|booking_policy|next_available|clinic_queue|appointment_attendance)$/.test(name))
        throw Error("Unsupported test RPC");
      const keys = Object.keys(args);
      const sql = `select public.${name}(${keys.map((key, i) => `${key}=>$${i + 1}`).join(",")}) as data`;
      const result = await db.query<any>(
        sql,
        Object.values(args).map((v) =>
          typeof v === "object" && v !== null ? JSON.stringify(v) : v,
        ),
      );
      return { data: result.rows[0].data, error: null };
    } catch (error: any) {
      return {
        data: null,
        error: {
          code: error.code,
          message: error.message,
          details: error.detail,
        },
      };
    }
  },
  from: (table: string) => {
    if (!["clinics", "staff_memberships"].includes(table))
      throw Error("Unsupported test table");
    const conditions: string[] = [],
      values: any[] = [];
    let order = "";
    const query: any = {
      select: () => query,
      eq: (key: string, value: any) => {
        conditions.push(`${key}=$${values.push(value)}`);
        return query;
      },
      in: (key: string, value: any[]) => {
        conditions.push(`${key}=any($${values.push(value)}::uuid[])`);
        return query;
      },
      order: (key: string) => {
        order = key;
        return query;
      },
      then: (resolve: any, reject: any) =>
        db
          .query(
            `select * from public.${table}${conditions.length ? " where " + conditions.join(" and ") : ""}${order ? " order by " + order : ""}`,
            values,
          )
          .then(
            (result) => resolve({ data: result.rows, error: null }),
            reject,
          ),
    };
    return query;
  },
} as unknown as SupabaseClient;
const config = {
  NODE_ENV: "test" as const,
  PORT: 3011,
  CORS_ORIGINS: "http://127.0.0.1:5178",
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_ANON_KEY: "test-only",
  SUPABASE_SERVICE_ROLE_KEY: "test-only",
};
const app = createApp(
  config,
  { list: async () => [], get: async () => ({}), settings: async () => ({}) },
  undefined,
  undefined,
  adminRoutes(fake),
  bookingRoutes(fake),
  doctorRoutes(fake),
);
const server = app.listen(3011, "127.0.0.1", () =>
  console.log("Browser QA API ready on 3011"),
);
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () =>
    server.close(async () => {
      await db.close();
      process.exit(0);
    }),
  );
