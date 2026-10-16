import { doctorRoutes } from "../src/modules/doctor/routes.js";
import { it, expect, vi } from "vitest";
import request from "supertest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createApp } from "../src/app.js";
import { adminRoutes } from "../src/modules/admin/routes.js";
import { bookingRoutes } from "../src/modules/appointments/routes.js";
const clinic = "12a30244-3000-4000-8000-000000000001",
  other = "12a30244-3000-4000-8000-000000000002",
  actor = "10000000-0000-4000-8000-000000000001",
  doctor = "10000000-0000-4000-8000-000000000002",
  service = "10000000-0000-4000-8000-000000000003";
const config = {
  NODE_ENV: "test" as const,
  PORT: 3000,
  CORS_ORIGINS: "http://localhost:5173",
  SUPABASE_URL: "http://localhost:54321",
  SUPABASE_ANON_KEY: "test",
  SUPABASE_SERVICE_ROLE_KEY: "test",
};
function fixture(role: string = "RECEPTIONIST") {
  const rpc = vi.fn(async () => ({ data: { id: "record" }, error: null })),
    db = {
      auth: {
        getUser: async (token: string) => ({
          data: { user: token === "verified" ? { id: actor } : null },
          error: null,
        }),
      },
      from: () => ({
        select: () => ({
          eq: () => ({
            eq: async () => ({
              data: [
                {
                  id: "m",
                  role,
                  clinic_id: clinic,
                  doctor_id: role === "DOCTOR" ? doctor : null,
                },
              ],
              error: null,
            }),
          }),
        }),
      }),
      rpc,
    } as unknown as SupabaseClient;
  return {
    rpc,
    app: createApp(
      config,
      {
        list: async () => [],
        get: async () => ({}),
        settings: async () => ({}),
      },
      undefined,
      undefined,
      adminRoutes(db),
      bookingRoutes(db),
      doctorRoutes(db),
    ),
  };
}
it("rejects expired tokens and foreign clinics before dispatching mutations", async () => {
  const { app, rpc } = fixture();
  expect(
    (
      await request(app)
        .post(`/api/v1/admin/clinics/${clinic}/appointments`)
        .set("Authorization", "Bearer expired")
        .send({})
    ).status,
  ).toBe(401);
  expect(
    (
      await request(app)
        .get(`/api/v1/admin/clinics/${other}/appointments`)
        .set("Authorization", "Bearer verified")
    ).status,
  ).toBe(403);
  expect(rpc).not.toHaveBeenCalled();
});
it("rejects receptionist staff management and doctor booking before dispatch", async () => {
  for (const [role, path] of [
    ["RECEPTIONIST", "staff"],
    ["DOCTOR", "appointments"],
  ]) {
    const { app, rpc } = fixture(role);
    expect(
      (
        await request(app)
          .post(`/api/v1/admin/clinics/${clinic}/${path}`)
          .set("Authorization", "Bearer verified")
          .send({})
      ).status,
    ).toBe(403);
    expect(rpc).not.toHaveBeenCalled();
  }
});
it("validates availability parameters and sends only the verified actor to SQL", async () => {
  const { app, rpc } = fixture();
  const response = await request(app)
    .get(`/api/v1/admin/clinics/${clinic}/availability`)
    .set("Authorization", "Bearer verified")
    .query({ doctor_id: doctor, service_id: service, date: "2026-10-20" });
  expect(response.status).toBe(200);
  expect(rpc).toHaveBeenCalledWith("admin_availability", {
    p_actor: actor,
    p_clinic: clinic,
    p_doctor: doctor,
    p_service: service,
    p_date: "2026-10-20",
  });
  expect(
    (
      await request(app)
        .get(`/api/v1/admin/clinics/${clinic}/availability`)
        .set("Authorization", "Bearer verified")
        .query({ doctor_id: "invalid" })
    ).status,
  ).toBe(400);
});
it("returns localized-domain conflict codes without leaking raw database details", async () => {
  const { app, rpc } = fixture();
  rpc.mockResolvedValueOnce({
    data: null,
    error: {
      code: "P0001",
      message: "SLOT_UNAVAILABLE",
      details: "private database detail",
    },
  } as any);
  const response = await request(app)
    .post(`/api/v1/admin/clinics/${clinic}/appointments`)
    .set("Authorization", "Bearer verified")
    .send({
      patient_id: actor,
      doctor_id: doctor,
      service_id: service,
      starts_at: "2026-10-20T06:00:00Z",
    });
  expect(response.status).toBe(409);
  expect(response.body.error.code).toBe("SLOT_UNAVAILABLE");
  expect(JSON.stringify(response.body)).not.toContain(
    "private database detail",
  );
});
it("never accepts a patient identity supplied to the patient booking endpoint", async () => {
  const { app, rpc } = fixture();
  const response = await request(app)
    .post(`/api/v1/clinics/${clinic}/booking/appointments`)
    .set("Authorization", "Bearer verified")
    .send({
      patient_id: doctor,
      doctor_id: doctor,
      service_id: service,
      starts_at: "2026-10-20T06:00:00Z",
    });
  expect(response.status).toBe(400);
  expect(rpc).not.toHaveBeenCalled();
  const ok = await request(app)
    .post(`/api/v1/clinics/${clinic}/booking/appointments`)
    .set("Authorization", "Bearer verified")
    .send({
      doctor_id: doctor,
      service_id: service,
      starts_at: "2026-10-20T06:00:00Z",
    });
  expect(ok.status).toBe(201);
  expect(rpc.mock.calls[0]?.[1]).toMatchObject({
    p_actor: actor,
    p_clinic: clinic,
  });
});

it("doctor routes derive identity and reject injected identity filters and foreign clinics", async () => {
  const { app, rpc } = fixture("DOCTOR");
  const own = await request(app)
    .get("/api/v1/doctor/appointments")
    .query({ clinic_id: clinic })
    .set("Authorization", "Bearer verified");
  expect(own.status).toBe(200);
  expect(rpc).toHaveBeenCalledWith(
    "doctor_read",
    expect.objectContaining({
      p_actor: actor,
      p_clinic: clinic,
      p_resource: "appointments",
    }),
  );
  expect(
    (
      await request(app)
        .get("/api/v1/doctor/appointments")
        .query({ clinic_id: clinic, doctor_id: doctor })
        .set("Authorization", "Bearer verified")
    ).status,
  ).toBe(400);
  expect(
    (
      await request(app)
        .get("/api/v1/doctor/appointments")
        .query({ clinic_id: other })
        .set("Authorization", "Bearer verified")
    ).status,
  ).toBe(403);
});
it("doctor HTTP rejects direct cancellation and malformed schedule requests", async () => {
  const { app, rpc } = fixture("DOCTOR");
  expect(
    (
      await request(app)
        .patch(`/api/v1/doctor/appointments/${service}/status`)
        .set("Authorization", "Bearer verified")
        .send({
          clinic_id: clinic,
          status: "cancelled",
          expected_updated_at: new Date().toISOString(),
        })
    ).status,
  ).toBe(400);
  expect(
    (
      await request(app)
        .post("/api/v1/doctor/schedule-change-requests")
        .set("Authorization", "Bearer verified")
        .send({
          clinic_id: clinic,
          kind: "schedule",
          reason: "Change my hours",
          payload: {
            weekly: [
              { weekday: 1, starts_at: "12:00", ends_at: "10:00", breaks: [] },
            ],
            exceptions: [],
          },
        })
    ).status,
  ).toBe(400);
  expect(rpc).not.toHaveBeenCalled();
});
it("receptionist cannot access doctor routes or approve schedule requests", async () => {
  const { app, rpc } = fixture("RECEPTIONIST");
  expect(
    (
      await request(app)
        .get("/api/v1/doctor/me")
        .query({ clinic_id: clinic })
        .set("Authorization", "Bearer verified")
    ).status,
  ).toBe(403);
  expect(
    (
      await request(app)
        .patch(`/api/v1/admin/clinics/${clinic}/doctor-requests/${service}`)
        .set("Authorization", "Bearer verified")
        .send({ approve: true, note: "" })
    ).status,
  ).toBe(403);
  expect(rpc).not.toHaveBeenCalled();
});
it("public slots require no patient identity while direct schedule writes require a verified doctor", async () => {
  const { app, rpc } = fixture("DOCTOR");
  expect(
    (
      await request(app)
        .get(`/api/v1/clinics/${clinic}/availability`)
        .query({ doctor_id: doctor, service_id: service, date: "2026-12-01" })
    ).status,
  ).toBe(200);
  expect(rpc).toHaveBeenCalledWith(
    "public_availability",
    expect.objectContaining({ p_clinic: clinic, p_doctor: doctor }),
  );
  const saved = await request(app)
    .put("/api/v1/doctor/schedule")
    .set("Authorization", "Bearer verified")
    .send({ clinic_id: clinic, schedule: { weekly: [], exceptions: [] } });
  expect(saved.status).toBe(200);
  expect(rpc).toHaveBeenCalledWith("doctor_schedule_save", {
    p_actor: actor,
    p_clinic: clinic,
    p_input: { weekly: [], exceptions: [] },
  });
  expect(
    (
      await request(app)
        .put("/api/v1/doctor/schedule")
        .set("Authorization", "Bearer verified")
        .send({
          clinic_id: clinic,
          doctor_id: other,
          schedule: { weekly: [], exceptions: [] },
        })
    ).status,
  ).toBe(400);
});
it("doctor schedule API accepts a full-day end boundary and late-night working hours", async () => {
  const { app, rpc } = fixture("DOCTOR");
  const schedule = {
    weekly: [
      { weekday: 1, starts_at: "00:00", ends_at: "24:00", breaks: [] },
      { weekday: 2, starts_at: "23:00", ends_at: "24:00", breaks: [] },
    ],
    exceptions: [],
  };
  expect(
    (
      await request(app)
        .put("/api/v1/doctor/schedule")
        .set("Authorization", "Bearer verified")
        .send({ clinic_id: clinic, schedule })
    ).status,
  ).toBe(200);
  expect(rpc).toHaveBeenCalledWith(
    "doctor_schedule_save",
    expect.objectContaining({ p_input: schedule }),
  );
});
