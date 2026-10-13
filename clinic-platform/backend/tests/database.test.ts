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

const workspaceDoctorUser = "51000000-0000-4000-8000-000000000001",
  otherDoctorUser = "51000000-0000-4000-8000-000000000002",
  ownPatient = "51000000-0000-4000-8000-000000000003",
  foreignPatient = "51000000-0000-4000-8000-000000000004";
async function doctorFixture(run: (f: any) => Promise<void>) {
  await db.exec("begin");
  try {
    await db.exec(
      "update public.system_settings set booking_enabled=true,booking_horizon_days=90 where id",
    );
    const other = (
      await db.query<any>(
        `select ds.doctor_id,s.id service_id from public.doctor_services ds join public.services s on s.id=ds.service_id and s.clinic_id=ds.clinic_id where ds.clinic_id=$1 and ds.doctor_id<>$2 and ds.active and s.active limit 1`,
        [clinic, doctor],
      )
    ).rows[0];
    await db.query(`insert into auth.users(id) values($1),($2),($3),($4)`, [
      workspaceDoctorUser,
      otherDoctorUser,
      ownPatient,
      foreignPatient,
    ]);
    await db.query(
      `insert into public.staff_memberships(user_id,clinic_id,role,doctor_id) values($1,$3,'DOCTOR',$4),($2,$3,'DOCTOR',$5)`,
      [workspaceDoctorUser, otherDoctorUser, clinic, doctor, other.doctor_id],
    );
    await db.query(`select public.admin_patient_link($1,$2,$3,$4)`, [
      actor,
      clinic,
      ownPatient,
      JSON.stringify({ full_name: "Doctor A patient", phone: "+70000000511" }),
    ]);
    await db.query(`select public.admin_patient_link($1,$2,$3,$4)`, [
      actor,
      clinic,
      foreignPatient,
      JSON.stringify({ full_name: "Doctor B patient", phone: "+70000000512" }),
    ]);
    const insert = async (d: string, s: string, p: string, past: boolean) =>
      (
        await db.query<any>(
          `insert into public.appointments(clinic_id,doctor_id,patient_id,service_id,starts_at,ends_at,status,price_rub) select $1,$2,$3,id,now()+case when $5 then interval '-2 days' else interval '20 days' end,now()+case when $5 then interval '-2 days' else interval '20 days' end+interval '30 minutes','confirmed',price_rub from public.services where id=$4 returning *`,
          [clinic, d, p, s, past],
        )
      ).rows[0];
    const own = await insert(doctor, service, ownPatient, false),
      foreign = await insert(
        other.doctor_id,
        other.service_id,
        foreignPatient,
        false,
      ),
      past = await insert(doctor, service, ownPatient, true);
    const original = db.query.bind(db);
    db.query = (async (...args: any[]) => {
      await original("savepoint doctor_assertion");
      try {
        const result = await (original as any)(...args);
        await original("release savepoint doctor_assertion");
        return result;
      } catch (error) {
        await original("rollback to savepoint doctor_assertion");
        await original("release savepoint doctor_assertion");
        throw error;
      }
    }) as typeof db.query;
    try {
      await run({ own, foreign, past, other });
    } finally {
      db.query = original;
    }
  } finally {
    await db.exec("rollback");
  }
}
const doctorRead = async (resource: string, q: any = {}) =>
  (
    await db.query<any>("select public.doctor_read($1,$2,$3,$4) d", [
      workspaceDoctorUser,
      clinic,
      resource,
      JSON.stringify(q),
    ])
  ).rows[0].d;
it("doctor endpoints isolate own appointments even with a separate admin role", () =>
  doctorFixture(async ({ own, foreign }) => {
    await db.query(
      `insert into public.staff_memberships(user_id,clinic_id,role) values($1,$2,'CLINIC_ADMIN')`,
      [workspaceDoctorUser, clinic],
    );
    const list = await doctorRead("appointments");
    expect(list.items.some((r: any) => r.id === own.id)).toBe(true);
    expect(list.items.some((r: any) => r.id === foreign.id)).toBe(false);
    await expect(doctorRead("appointment", { id: foreign.id })).rejects.toThrow(
      "NOT_FOUND",
    );
    expect((await doctorRead("appointment", { id: own.id })).id).toBe(own.id);
  }));
it("doctor patient relationships and history exclude unrelated clinic patients", () =>
  doctorFixture(async () => {
    const list = await doctorRead("patients");
    expect(list.items.some((p: any) => p.id === ownPatient)).toBe(true);
    expect(list.items.some((p: any) => p.id === foreignPatient)).toBe(false);
    expect(
      list.items.find((p: any) => p.id === ownPatient).appointment_count,
    ).toBe(2);
    expect(list.items[0]).not.toHaveProperty("phone");
    await expect(doctorRead("patient", { id: foreignPatient })).rejects.toThrow(
      "NOT_FOUND",
    );
    expect(
      (await doctorRead("appointments", { patient_id: foreignPatient })).items,
    ).toEqual([]);
  }));
it("doctor identity rejects unauthorized clinics and supports a valid second assignment", () =>
  doctorFixture(async () => {
    const other = (
      await db.query<any>(
        "select id from public.clinics where id<>$1 limit 1",
        [clinic],
      )
    ).rows[0].id;
    await expect(
      db.query("select public.doctor_identity($1,$2)", [
        workspaceDoctorUser,
        other,
      ]),
    ).rejects.toThrow("FORBIDDEN");
    await db.query(
      "insert into public.doctor_clinics(clinic_id,doctor_id) values($1,$2) on conflict do nothing",
      [other, doctor],
    );
    {
      await db.query(
        `insert into public.staff_memberships(user_id,clinic_id,role,doctor_id) values($1,$2,'DOCTOR',$3)`,
        [workspaceDoctorUser, other, doctor],
      );
      expect(
        (
          await db.query<any>("select public.doctor_identity($1,$2) id", [
            workspaceDoctorUser,
            other,
          ])
        ).rows[0].id,
      ).toBe(doctor);
    }
  }));
it("doctor dashboard aggregates match only that doctor SQL records", () =>
  doctorFixture(async () => {
    const day = (
      await db.query<any>(
        `select (now() at time zone timezone)::date::text as day from public.clinics where id=$1`,
        [clinic],
      )
    ).rows[0].day;
    const d = await doctorRead("dashboard", { from: day, to: day });
    const expected = (
      await db.query<any>(
        `select count(distinct patient_id)::int patients,count(*) filter(where starts_at>now() and status in ('pending','confirmed'))::int upcoming from public.appointments where clinic_id=$1 and doctor_id=$2`,
        [clinic, doctor],
      )
    ).rows[0];
    expect(d.kpis.patients).toBe(expected.patients);
    expect(d.kpis.upcoming).toBe(expected.upcoming);
    expect(d.next.doctor_id).toBe(doctor);
    expect(d.schedule.weekly.length).toBeGreaterThan(0);
  }));
it("doctor calendar returns own events with schedule and exceptions", () =>
  doctorFixture(async ({ own, foreign }) => {
    const q = {
      from: new Date(Date.parse(own.starts_at) - 3600000).toISOString(),
      to: new Date(Date.parse(own.ends_at) + 3600000).toISOString(),
    };
    const c = await doctorRead("calendar", q);
    expect(c.items.map((r: any) => r.id)).toContain(own.id);
    expect(c.items.map((r: any) => r.id)).not.toContain(foreign.id);
    expect(c.schedule).toHaveProperty("exceptions");
  }));
it("doctor status changes enforce ownership, valid transitions, history and audit", () =>
  doctorFixture(async ({ own, foreign, past }) => {
    const change = async (a: any, status: string) =>
      db.query<any>("select public.doctor_status($1,$2,$3,$4) a", [
        workspaceDoctorUser,
        clinic,
        a.id,
        JSON.stringify({ status, expected_updated_at: a.updated_at }),
      ]);
    await expect(change(foreign, "completed")).rejects.toThrow("NOT_FOUND");
    await expect(change(own, "cancelled")).rejects.toThrow("FORBIDDEN");
    await expect(change(own, "completed")).rejects.toThrow(
      "INVALID_TRANSITION",
    );
    expect((await change(past, "completed")).rows[0].a.status).toBe(
      "completed",
    );
    expect(
      (
        await db.query(
          `select 1 from public.appointment_status_history where appointment_id=$1 and status='completed'`,
          [past.id],
        )
      ).rows.length,
    ).toBe(1);
    expect(
      (
        await db.query(
          `select 1 from public.audit_logs where resource_id=$1 and action='appointment.status_changed'`,
          [past.id],
        )
      ).rows.length,
    ).toBe(1);
  }));
it("schedule requests leave schedules unchanged until authorized admin approval", () =>
  doctorFixture(async () => {
    const schedule = await doctorRead("schedule");
    const proposed = {
      weekly: schedule.weekly.map((s: any) => ({
        weekday: s.weekday,
        starts_at: s.starts_at.slice(0, 5),
        ends_at: s.ends_at.slice(0, 5),
        breaks: s.breaks,
      })),
      exceptions: schedule.exceptions.map((e: any) => ({
        starts_at: e.starts_at,
        ends_at: e.ends_at,
        available: e.available,
      })),
    };
    const r = (
      await db.query<any>("select public.doctor_request($1,$2,$3,$4,$5) r", [
        workspaceDoctorUser,
        clinic,
        "schedule",
        JSON.stringify(proposed),
        "Please keep my current working hours",
      ])
    ).rows[0].r;
    expect(await doctorRead("schedule")).toEqual(schedule);
    await expect(
      db.query("select public.admin_review_doctor_request($1,$2,$3,true,$4)", [
        workspaceDoctorUser,
        clinic,
        r.id,
        "approved",
      ]),
    ).rejects.toThrow("FORBIDDEN");
    // The deliberately off-grid fixture appointment makes approval conflict: rejection remains safe.
    expect(
      (
        await db.query<any>(
          "select public.admin_review_doctor_request($1,$2,$3,false,$4) r",
          [actor, clinic, r.id, "Please discuss the requested hours"],
        )
      ).rows[0].r.status,
    ).toBe("rejected");
    expect(await doctorRead("schedule")).toEqual(schedule);
    expect(
      (await doctorRead("notifications")).items.some(
        (n: any) => n.action === "request.rejected",
      ),
    ).toBe(true);
  }));
it("leave approval checks appointments atomically and rejects conflicts", () =>
  doctorFixture(async ({ own }) => {
    const r = (
      await db.query<any>("select public.doctor_request($1,$2,$3,$4,$5) r", [
        workspaceDoctorUser,
        clinic,
        "vacation",
        JSON.stringify({ starts_at: own.starts_at, ends_at: own.ends_at }),
        "Vacation overlaps a booked appointment",
      ])
    ).rows[0].r;
    const old = await doctorRead("schedule");
    await expect(
      db.query("select public.admin_review_doctor_request($1,$2,$3,true,$4)", [
        actor,
        clinic,
        r.id,
        "approved",
      ]),
    ).rejects.toThrow("SCHEDULE_CONFLICT");
    expect(await doctorRead("schedule")).toEqual(old);
    expect(
      (await doctorRead("requests")).items.find((x: any) => x.id === r.id)
        .status,
    ).toBe("pending");
    const free = (
      await db.query<any>("select public.doctor_request($1,$2,$3,$4,$5) r", [
        workspaceDoctorUser,
        clinic,
        "day_off",
        JSON.stringify({
          starts_at: new Date(Date.now() + 25 * 86400000).toISOString(),
          ends_at: new Date(Date.now() + 25 * 86400000 + 3600000).toISOString(),
        }),
        "Requested free afternoon",
      ])
    ).rows[0].r;
    expect(
      (
        await db.query<any>(
          "select public.admin_review_doctor_request($1,$2,$3,true,$4) r",
          [actor, clinic, free.id, "approved"],
        )
      ).rows[0].r.status,
    ).toBe("approved");
    expect(
      (await doctorRead("schedule")).exceptions.some((e: any) => !e.available),
    ).toBe(true);
  }));
it("doctor requests broadcast identifiers only to own doctor and authorized administrators", () =>
  doctorFixture(async () => {
    await db.exec("delete from realtime.messages");
    await db.query("select public.doctor_request($1,$2,$3,$4,$5)", [
      workspaceDoctorUser,
      clinic,
      "day_off",
      JSON.stringify({
        starts_at: new Date(Date.now() + 26 * 86400000).toISOString(),
        ends_at: new Date(Date.now() + 26 * 86400000 + 3600000).toISOString(),
      }),
      "A requested day off",
    ]);
    const messages = (await db.query<any>("select * from realtime.messages"))
      .rows;
    expect(
      messages.some(
        (m) => m.topic === `staff:${clinic}:${workspaceDoctorUser}`,
      ),
    ).toBe(true);
    expect(
      messages.some((m) => m.topic === `staff:${clinic}:${otherDoctorUser}`),
    ).toBe(false);
    for (const m of messages) {
      expect(Object.keys(m.payload).sort()).toEqual([
        "clinic_id",
        "event_id",
        "request_id",
      ]);
    }
  }));
it("doctor account cannot be linked to a different identity in another clinic", () =>
  doctorFixture(async ({ other }) => {
    const c = (
      await db.query<any>(
        "select id from public.clinics where id<>$1 limit 1",
        [clinic],
      )
    ).rows[0].id;
    await expect(
      db.query(
        `insert into public.staff_memberships(user_id,clinic_id,role,doctor_id) values($1,$2,'DOCTOR',$3)`,
        [workspaceDoctorUser, c, other.doctor_id],
      ),
    ).rejects.toThrow("VALIDATION_ERROR");
  }));
it("doctor rescheduling requires review and approval uses real booking availability", () =>
  doctorFixture(async ({ own }) => {
    let target: string | undefined;
    for (let offset = 1; offset < 8; offset++) {
      const day = (
        await db.query<any>("select (current_date+$1::integer)::text as day", [
          offset,
        ])
      ).rows[0].day;
      const slots = (
        await db.query<any>(
          "select public.admin_availability($1,$2,$3,$4,$5) slots",
          [actor, clinic, doctor, service, day],
        )
      ).rows[0].slots;
      if (slots.length) {
        target = slots[0].starts_at;
        break;
      }
    }
    expect(target).toBeDefined();
    const r = (
      await db.query<any>("select public.doctor_request($1,$2,$3,$4,$5) r", [
        workspaceDoctorUser,
        clinic,
        "reschedule",
        JSON.stringify({
          appointment_id: own.id,
          starts_at: target,
          expected_updated_at: own.updated_at,
        }),
        "Please move my appointment to the available time",
      ])
    ).rows[0].r;
    expect(
      Date.parse((await doctorRead("appointment", { id: own.id })).starts_at),
    ).toBe(new Date(own.starts_at).getTime());
    expect(
      (
        await db.query<any>(
          "select public.admin_review_doctor_request($1,$2,$3,true,$4) r",
          [actor, clinic, r.id, "Available slot approved"],
        )
      ).rows[0].r.status,
    ).toBe("approved");
    const updated = await doctorRead("appointment", { id: own.id });
    expect(Date.parse(updated.starts_at)).toBe(Date.parse(target!));
    await expect(
      db.query("select public.admin_review_doctor_request($1,$2,$3,true,$4)", [
        actor,
        clinic,
        r.id,
        "second approval",
      ]),
    ).rejects.toThrow("STALE_APPOINTMENT");
  }));
it("shared patient booking emits a private update only for the assigned doctor", () =>
  doctorFixture(async () => {
    let target: string | undefined;
    for (let offset = 1; offset < 8; offset++) {
      const day = (
        await db.query<any>("select (current_date+$1::integer)::text as day", [
          offset,
        ])
      ).rows[0].day;
      const slots = (
        await db.query<any>(
          "select public.patient_availability($1,$2,$3,$4,$5) slots",
          [ownPatient, clinic, doctor, service, day],
        )
      ).rows[0].slots;
      if (slots.length) {
        target = slots[0].starts_at;
        break;
      }
    }
    expect(target).toBeDefined();
    await db.exec("delete from realtime.messages");
    const booked = (
      await db.query<any>("select public.patient_book($1,$2,$3) a", [
        ownPatient,
        clinic,
        JSON.stringify({
          doctor_id: doctor,
          service_id: service,
          starts_at: target,
        }),
      ])
    ).rows[0].a;
    expect(
      (await doctorRead("appointments")).items.some(
        (a: any) => a.id === booked.id,
      ),
    ).toBe(true);
    const messages = (
      await db.query<any>("select topic,payload from realtime.messages")
    ).rows;
    expect(
      messages.some(
        (m) => m.topic === `staff:${clinic}:${workspaceDoctorUser}`,
      ),
    ).toBe(true);
    expect(
      messages.some((m) => m.topic === `staff:${clinic}:${otherDoctorUser}`),
    ).toBe(false);
    expect(
      messages
        .filter((m) => m.topic.startsWith("staff:"))
        .every((m) => !("patient_name" in m.payload)),
    ).toBe(true);
  }));
it("schedule approval cannot overwrite intervening administrator edits", () =>
  doctorFixture(async () => {
    const schedule = await doctorRead("schedule");
    const payload = {
      weekly: schedule.weekly.map((s: any) => ({
        weekday: s.weekday,
        starts_at: s.starts_at.slice(0, 5),
        ends_at: s.ends_at.slice(0, 5),
        breaks: s.breaks,
      })),
      exceptions: [],
    };
    const r = (
      await db.query<any>("select public.doctor_request($1,$2,$3,$4,$5) r", [
        workspaceDoctorUser,
        clinic,
        "schedule",
        JSON.stringify(payload),
        "Please review my weekly hours",
      ])
    ).rows[0].r;
    await db.query(
      "update public.doctor_schedules set ends_at=ends_at+interval '15 minutes' where clinic_id=$1 and doctor_id=$2",
      [clinic, doctor],
    );
    const edited = await doctorRead("schedule");
    await expect(
      db.query("select public.admin_review_doctor_request($1,$2,$3,true,$4)", [
        actor,
        clinic,
        r.id,
        "approve stale proposal",
      ]),
    ).rejects.toThrow("STALE_APPOINTMENT");
    expect(await doctorRead("schedule")).toEqual(edited);
  }));
it("browser database roles cannot invoke doctor RPCs or read change-request tables", async () => {
  await db.exec("set role authenticated");
  try {
    await expect(
      db.query("select public.doctor_read($1,$2,$3)", [
        workspaceDoctorUser,
        clinic,
        "patients",
      ]),
    ).rejects.toThrow(/permission denied/);
    await expect(
      db.query("select * from public.doctor_change_requests"),
    ).rejects.toThrow(/permission denied/);
  } finally {
    await db.exec("reset role");
  }
});
