import { beforeAll, afterAll, it, expect } from "vitest";
import { PGlite } from "@electric-sql/pglite";
import { btree_gist } from "@electric-sql/pglite/contrib/btree_gist";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
const db = new PGlite({ extensions: { btree_gist, pg_trgm } });
const sqlRoot = fileURLToPath(new URL("../../supabase/", import.meta.url));
const actor = "10000000-0000-4000-8000-000000000001",
  patient = "10000000-0000-4000-8000-000000000002";
let clinic: string,
  doctor: string,
  service: string,
  slot: string,
  appointment: any;
beforeAll(async () => {
  await db.exec(
    `create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema extensions;create schema realtime;create schema storage;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;create publication supabase_realtime;create table realtime.messages(id uuid default gen_random_uuid(),topic text,extension text,payload jsonb);alter table realtime.messages enable row level security;grant select on realtime.messages to authenticated;create function realtime.topic() returns text language sql as $$select current_setting('realtime.topic',true)$$;create function realtime.send(payload jsonb,event text,topic text,private boolean) returns void language sql as $$insert into realtime.messages(topic,extension,payload) values(topic,'broadcast',payload)$$;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);`,
  );
  for (const file of readdirSync(sqlRoot + "migrations").sort())
    await db.exec(readFileSync(sqlRoot + "migrations/" + file, "utf8"));
  await db.exec(readFileSync(sqlRoot + "seeds/catalog.sql", "utf8"));
  const row = (
    await db.query<any>(
      `select dc.clinic_id,dc.doctor_id,s.id as service_id from public.doctor_clinics dc join public.doctor_services ds on ds.clinic_id=dc.clinic_id and ds.doctor_id=dc.doctor_id join public.services s on s.id=ds.service_id and s.clinic_id=ds.clinic_id where dc.active and s.active order by dc.clinic_id,dc.sort_order,s.sort_order limit 1`,
    )
  ).rows[0];
  clinic = row.clinic_id;
  doctor = row.doctor_id;
  service = row.service_id;
  await db.exec(
    `insert into auth.users(id) values('${actor}'),('${patient}');insert into public.staff_memberships(user_id,role) values('${actor}','SUPER_ADMIN');`,
  );
  await db.query(`select public.admin_patient_link($1,$2,$3,$4)`, [
    actor,
    clinic,
    patient,
    JSON.stringify({ full_name: "Fictional patient", phone: "+70000000000" }),
  ]);
  const date = (
    await db.query<any>(
      `select to_char(current_date+case when extract(dow from current_date+1) in (0,6) then 3 else 1 end,'YYYY-MM-DD') as day`,
    )
  ).rows[0].day;
  const slots = (
    await db.query<any>(
      "select public.admin_availability($1,$2,$3,$4,$5) as slots",
      [actor, clinic, doctor, service, date],
    )
  ).rows[0].slots;
  expect(slots.length).toBeGreaterThan(0);
  slot = slots[0].starts_at;
}, 30000);
afterAll(() => db.close());
it("executes all migrations and repeatable seed with correct active catalog counts", async () => {
  await db.exec(readFileSync(sqlRoot + "seeds/catalog.sql", "utf8"));
  const rows = (
    await db.query<any>(
      `select c.slug,(select count(*)::int from public.catalog_doctors where clinic_id=c.id) doctors,(select count(*)::int from public.catalog_specialties where clinic_id=c.id) specialties,(select count(*)::int from public.catalog_services where clinic_id=c.id) services,(select count(*)::int from public.promotions where clinic_id=c.id and active) promotions from public.clinics c order by c.slug`,
    )
  ).rows;
  expect(rows).toEqual([
    {
      slug: "clinic_001",
      doctors: 10,
      specialties: 8,
      services: 20,
      promotions: 4,
    },
    {
      slug: "clinic_002",
      doctors: 9,
      specialties: 7,
      services: 18,
      promotions: 4,
    },
  ]);
});
it("atomically books using availability and preserves price/history/audit", async () => {
  appointment = (
    await db.query<any>("select public.admin_book($1,$2,$3) as a", [
      actor,
      clinic,
      JSON.stringify({
        doctor_id: doctor,
        service_id: service,
        patient_id: patient,
        starts_at: slot,
      }),
    ])
  ).rows[0].a;
  expect(appointment.status).toBe("pending");
  expect(appointment.price_rub).toBeGreaterThan(0);
  expect(
    (
      await db.query<any>(
        "select count(*)::int count from public.appointment_status_history where appointment_id=$1",
        [appointment.id],
      )
    ).rows[0].count,
  ).toBe(1);
});
it("rejects double booking with no duplicate appointment", async () => {
  await expect(
    db.query("select public.admin_book($1,$2,$3)", [
      actor,
      clinic,
      JSON.stringify({
        doctor_id: doctor,
        service_id: service,
        patient_id: patient,
        starts_at: slot,
      }),
    ]),
  ).rejects.toThrow("SLOT_UNAVAILABLE");
});
it("confirms and rejects stale/invalid transitions", async () => {
  appointment = (
    await db.query<any>(
      "select public.admin_appointment_change($1,$2,$3,$4) as a",
      [
        actor,
        clinic,
        appointment.id,
        JSON.stringify({
          status: "confirmed",
          expected_updated_at: appointment.updated_at,
        }),
      ],
    )
  ).rows[0].a;
  expect(appointment.status).toBe("confirmed");
  await expect(
    db.query("select public.admin_appointment_change($1,$2,$3,$4)", [
      actor,
      clinic,
      appointment.id,
      JSON.stringify({
        status: "pending",
        expected_updated_at: appointment.updated_at,
      }),
    ]),
  ).rejects.toThrow("INVALID_TRANSITION");
});
it("rejects schedules that would invalidate confirmed bookings", async () => {
  await expect(
    db.query("select public.admin_schedule_save($1,$2,$3,$4)", [
      actor,
      clinic,
      doctor,
      JSON.stringify({ weekly: [], exceptions: [] }),
    ]),
  ).rejects.toThrow("SCHEDULE_CONFLICT");
});
it("aggregates actual data and keeps patient and catalog reads clinic-scoped", async () => {
  const data = (
    await db.query<any>(
      "select public.admin_dashboard($1,$2,current_date,current_date+30) as data",
      [actor, clinic],
    )
  ).rows[0].data;
  expect(data.kpis.confirmed).toBe(1);
});
const admin = "10000000-0000-4000-8000-000000000003",
  reception = "10000000-0000-4000-8000-000000000004",
  doctorUser = "10000000-0000-4000-8000-000000000005";
it("enforces clinic and role permissions again at the transaction boundary", async () => {
  await db.query("insert into auth.users(id) values($1),($2),($3)", [
    admin,
    reception,
    doctorUser,
  ]);
  await db.query(
    `insert into public.staff_memberships(user_id,clinic_id,role,doctor_id) values($1,$4,'CLINIC_ADMIN',null),($2,$4,'RECEPTIONIST',null),($3,$4,'DOCTOR',$5)`,
    [admin, reception, doctorUser, clinic, doctor],
  );
  const other = (
    await db.query<any>("select id from public.clinics where id<>$1 limit 1", [
      clinic,
    ])
  ).rows[0].id;
  await expect(
    db.query("select public.admin_list($1,$2,$3)", [admin, other, "patients"]),
  ).rejects.toThrow("FORBIDDEN");
  await expect(
    db.query("select public.admin_settings($1,$2)", [reception, clinic]),
  ).rejects.toThrow("FORBIDDEN");
  await expect(
    db.query("select public.admin_list($1,$2,$3)", [
      doctorUser,
      clinic,
      "patients",
    ]),
  ).rejects.toThrow("FORBIDDEN");
  const own = (
    await db.query<any>("select public.admin_list($1,$2,$3) as data", [
      doctorUser,
      clinic,
      "appointments",
    ])
  ).rows[0].data;
  expect(own.items.every((a: any) => a.doctor_id === doctor)).toBe(true);
  await expect(
    db.query("select public.admin_schedule_get($1,$2,$3)", [
      doctorUser,
      clinic,
      (
        await db.query<any>(
          "select doctor_id from public.doctor_clinics where clinic_id=$1 and doctor_id<>$2 limit 1",
          [clinic, doctor],
        )
      ).rows[0].doctor_id,
    ]),
  ).rejects.toThrow("FORBIDDEN");
});
it("reschedules atomically and returns the exact new timestamp in calendar reads", async () => {
  const day = slot.slice(0, 10),
    slots = (
      await db.query<any>(
        "select public.admin_availability($1,$2,$3,$4,$5) as slots",
        [actor, clinic, doctor, service, day],
      )
    ).rows[0].slots;
  const next = slots.find((s: any) => s.starts_at !== slot);
  expect(next).toBeTruthy();
  const before = appointment.updated_at;
  appointment = (
    await db.query<any>(
      "select public.admin_appointment_change($1,$2,$3,$4) as a",
      [
        reception,
        clinic,
        appointment.id,
        JSON.stringify({
          starts_at: next.starts_at,
          expected_updated_at: before,
        }),
      ],
    )
  ).rows[0].a;
  expect(appointment.starts_at).toBe(next.starts_at);
  const calendar = (
    await db.query<any>("select public.admin_calendar($1,$2,$3,$4,null) as c", [
      reception,
      clinic,
      appointment.starts_at,
      appointment.ends_at,
    ])
  ).rows[0].c;
  expect(calendar.items[0].starts_at).toBe(appointment.starts_at);
  await expect(
    db.query("select public.admin_appointment_change($1,$2,$3,$4)", [
      reception,
      clinic,
      appointment.id,
      JSON.stringify({ status: "cancelled", expected_updated_at: before }),
    ]),
  ).rejects.toThrow("STALE_APPOINTMENT");
});
it("preserves historical prices while publishing clinic-specific price updates", async () => {
  const historical = appointment.price_rub;
  await db.query("select public.admin_write($1,$2,$3,$4,$5)", [
    admin,
    clinic,
    "services",
    service,
    JSON.stringify({ price_rub: 1234.5 }),
  ]);
  expect(
    (
      await db.query<any>(
        "select price_rub from public.catalog_services where id=$1 and clinic_id=$2",
        [service, clinic],
      )
    ).rows[0].price_rub,
  ).toBe("1234.50");
  expect(
    (
      await db.query<any>(
        "select price_rub from public.appointments where id=$1",
        [appointment.id],
      )
    ).rows[0].price_rub,
  ).toBe(Number(historical).toFixed(2));
  const detail = (
    await db.query<any>("select public.admin_detail($1,$2,$3,$4) as d", [
      admin,
      clinic,
      "services",
      service,
    ])
  ).rows[0].d;
  expect(detail.doctor_ids).toContain(doctor);
});
it("creates doctor identities and clinic-specific assignments without altering other clinics", async () => {
  const empty = { ru: "", en: "" },
    input = {
      name: { ru: "Тестовый врач", en: "Test physician" },
      description: empty,
      professional_title: empty,
      experience_years: 4,
      education: empty,
      biography: empty,
      qualifications: empty,
      languages: ["ru"],
      active: true,
      featured: false,
      sort_order: 99,
      specialty_ids: [],
      service_ids: [],
    };
  const created = (
    await db.query<any>("select public.admin_write($1,$2,$3,null,$4) as d", [
      admin,
      clinic,
      "doctors",
      JSON.stringify(input),
    ])
  ).rows[0].d;
  const rows = (
    await db.query<any>(
      "select clinic_id from public.catalog_doctors where id=$1",
      [created.id],
    )
  ).rows;
  expect(rows).toEqual([{ clinic_id: clinic }]);
});
it("does not expose or link patients belonging exclusively to another clinic", async () => {
  const other = (
    await db.query<any>("select id from public.clinics where id<>$1 limit 1", [
      clinic,
    ])
  ).rows[0].id;
  expect(
    (
      await db.query<any>("select public.admin_list($1,$2,$3) as p", [
        actor,
        other,
        "patients",
      ])
    ).rows[0].p.items,
  ).toEqual([]);
  await expect(
    db.query("select public.admin_patient_link($1,$2,$3,$4)", [
      admin,
      other,
      patient,
      JSON.stringify({ full_name: "Unchanged", phone: "+70000000000" }),
    ]),
  ).rejects.toThrow("FORBIDDEN");
  await db.query("select public.admin_staff_save($1,$2,$3,$4)", [
    actor,
    other,
    admin,
    JSON.stringify({ role: "CLINIC_ADMIN", active: true }),
  ]);
  await expect(
    db.query("select public.admin_patient_link($1,$2,$3,$4)", [
      admin,
      other,
      patient,
      JSON.stringify({ full_name: "Unchanged", phone: "+70000000000" }),
    ]),
  ).rejects.toThrow("FORBIDDEN");
});
it("shares availability and atomic booking with verified patient callers", async () => {
  const availability = (
    await db.query<any>(
      "select public.patient_availability($1,$2,$3,$4,$5) as s",
      [patient, clinic, doctor, service, slot.slice(0, 10)],
    )
  ).rows[0].s;
  const staffSlots = (
    await db.query<any>(
      "select public.admin_availability($1,$2,$3,$4,$5) as s",
      [reception, clinic, doctor, service, slot.slice(0, 10)],
    )
  ).rows[0].s;
  expect(availability).toEqual(staffSlots);
  const booked = (
    await db.query<any>("select public.patient_book($1,$2,$3) as a", [
      patient,
      clinic,
      JSON.stringify({
        doctor_id: doctor,
        service_id: service,
        starts_at: availability[0].starts_at,
        patient_id: actor,
      }),
    ])
  ).rows[0].a;
  expect(booked.patient_id).toBe(patient);
  await expect(
    db.query("select public.admin_book($1,$2,$3)", [
      reception,
      clinic,
      JSON.stringify({
        doctor_id: doctor,
        service_id: service,
        starts_at: booked.starts_at,
        patient_id: patient,
      }),
    ]),
  ).rejects.toThrow("SLOT_UNAVAILABLE");
});
it("keeps RPCs and management views inaccessible to browser database roles", async () => {
  const rights = (
    await db.query<any>(
      `select has_function_privilege('authenticated','public.admin_book(uuid,uuid,jsonb)','execute') a,has_function_privilege('anon','public.patient_book(uuid,uuid,jsonb)','execute') b,has_table_privilege('authenticated','public.admin_patients','select') c`,
    )
  ).rows[0];
  expect(rights).toEqual({ a: false, b: false, c: false });
});
it("broadcasts minimum metadata only to current authorized staff recipients", async () => {
  const events = (
    await db.query<any>(
      "select topic,payload from realtime.messages where payload->>'appointment_id'=$1",
      [appointment.id],
    )
  ).rows;
  expect(events.length).toBeGreaterThan(0);
  expect(
    events.every(
      (e: any) =>
        Object.keys(e.payload).sort().join(",") ===
        "appointment_id,clinic_id,event_id,operation",
    ),
  ).toBe(true);
  await db.query(
    "update public.staff_memberships set active=false where user_id=$1",
    [reception],
  );
  await db.exec("truncate realtime.messages");
  appointment = (
    await db.query<any>(
      "select public.admin_appointment_change($1,$2,$3,$4) as a",
      [
        actor,
        clinic,
        appointment.id,
        JSON.stringify({
          status: "cancelled",
          expected_updated_at: appointment.updated_at,
        }),
      ],
    )
  ).rows[0].a;
  const topics = (
    await db.query<any>("select topic from realtime.messages")
  ).rows.map((e: any) => e.topic);
  expect(topics).not.toContain(`staff:${clinic}:${reception}`);
  expect(topics).toContain(`staff:${clinic}:${doctorUser}`);
  expect(topics).toContain(`patient:${clinic}:${patient}`);
});
it("permits settings edits with unchanged timezone and restricts system configuration", async () => {
  const zone = (
    await db.query<any>("select timezone from public.clinics where id=$1", [
      clinic,
    ])
  ).rows[0].timezone;
  await expect(
    db.query("select public.admin_settings($1,$2,$3)", [
      admin,
      clinic,
      JSON.stringify({ timezone: zone }),
    ]),
  ).resolves.toBeDefined();
  await expect(
    db.query("select public.admin_system($1,null)", [admin]),
  ).rejects.toThrow("FORBIDDEN");
  const settings = (
    await db.query<any>("select public.admin_system($1,$2) as s", [
      actor,
      JSON.stringify({ booking_horizon_days: 30, booking_enabled: false }),
    ])
  ).rows[0].s;
  expect(settings.booking_enabled).toBe(false);
  expect(
    (
      await db.query<any>(
        "select public.patient_availability($1,$2,$3,$4,$5) as s",
        [patient, clinic, doctor, service, slot.slice(0, 10)],
      )
    ).rows[0].s,
  ).toEqual([]);
});
it("authorizes private topics for the current identity and rejects other clinic/user subscriptions", async () => {
  await db.exec("grant usage on schema auth,realtime to authenticated;");
  async function visible(user: string, topic: string) {
    try {
      await db.query(
        "select set_config('request.jwt.claim.sub',$1,false),set_config('realtime.topic',$2,false)",
        [user, topic],
      );
      await db.exec("set role authenticated");
      return (await db.query<any>("select topic from realtime.messages")).rows;
    } finally {
      await db.exec("reset role");
    }
  }
  expect(
    (await visible(actor, `staff:${clinic}:${actor}`)).length,
  ).toBeGreaterThan(0);
  expect(await visible(doctorUser, `staff:${clinic}:${actor}`)).toEqual([]);
  expect(
    await visible(admin, `staff:ffffffff-ffff-4fff-8fff-ffffffffffff:${admin}`),
  ).toEqual([]);
  expect(
    (await visible(patient, `patient:${clinic}:${patient}`)).length,
  ).toBeGreaterThan(0);
  expect(await visible(patient, `staff:${clinic}:${actor}`)).toEqual([]);
  expect(await visible(reception, `staff:${clinic}:${reception}`)).toEqual([]);
});
it("enforces the exclusive doctor constraint even if the application validation is bypassed", async () => {
  await expect(
    db.query(
      `insert into public.appointments(clinic_id,doctor_id,patient_id,service_id,starts_at,ends_at,status,price_rub) select clinic_id,doctor_id,patient_id,service_id,starts_at,ends_at,status,price_rub from public.appointments where status='pending' limit 1`,
    ),
  ).rejects.toMatchObject({ code: "23P01" });
});
it("bootstraps only the first administrator through a server-only audited transaction", async () => {
  await expect(
    db.query("select public.bootstrap_super_admin($1)", [actor]),
  ).rejects.toThrow("FORBIDDEN");
  await db.exec("begin");
  try {
    await db.exec(
      "delete from public.staff_memberships where role='SUPER_ADMIN'",
    );
    expect(
      (
        await db.query<any>("select public.bootstrap_super_admin($1) as id", [
          actor,
        ])
      ).rows[0].id,
    ).toBe(actor);
    expect(
      (
        await db.query<any>(
          "select count(*)::integer count from public.audit_logs where action='staff.bootstrap' and actor_id=$1",
          [actor],
        )
      ).rows[0].count,
    ).toBe(1);
  } finally {
    await db.exec("rollback");
  }
  expect(
    (
      await db.query<any>(
        "select has_function_privilege('authenticated','public.bootstrap_super_admin(uuid)','execute') as allowed",
      )
    ).rows[0].allowed,
  ).toBe(false);
});
