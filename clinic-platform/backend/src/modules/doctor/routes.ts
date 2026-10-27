import { Router } from "express";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { authenticate } from "../../common/middleware/auth.js";
import { AuthorizationError } from "../../common/errors/app-error.js";
import { memberships } from "../admin/permissions.js";
import { adminRepository } from "../admin/repository.js";
import {
  medicalRecords,
  recordUpload,
} from "../medical_records/service.js";
import {
  uuid,
  scheduleSchema,
  calendarSchema,
  dashboardSchema,
} from "../admin/validation.js";
const instant = z.iso.datetime({ offset: true });
const list = z
  .object({
    clinic_id: uuid,
    page: z.coerce.number().int().min(1).max(100000).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    search: z.string().trim().max(100).optional(),
    status: z
      .enum(["pending", "confirmed", "completed", "cancelled", "no_show"])
      .optional(),
    service_id: uuid.optional(),
    patient_id: uuid.optional(),
    sort: z.enum(["newest", "oldest"]).optional(),
    from: instant.optional(),
    to: instant.optional(),
  })
  .strict()
  .refine((v) => !v.from || !v.to || Date.parse(v.to) > Date.parse(v.from));
const period = z
  .object({ starts_at: instant, ends_at: instant })
  .strict()
  .refine((v) => Date.parse(v.ends_at) > Date.parse(v.starts_at));
const reason = z.string().trim().min(5).max(2000);
export const doctorRequestSchema = z.discriminatedUnion("kind", [
  z
    .object({
      clinic_id: uuid,
      kind: z.literal("schedule"),
      payload: scheduleSchema,
      reason,
    })
    .strict(),
  z
    .object({
      clinic_id: uuid,
      kind: z.literal("day_off"),
      payload: period,
      reason,
    })
    .strict(),
  z
    .object({
      clinic_id: uuid,
      kind: z.literal("vacation"),
      payload: period,
      reason,
    })
    .strict(),
  z
    .object({
      clinic_id: uuid,
      kind: z.literal("reschedule"),
      payload: z
        .object({
          appointment_id: uuid,
          starts_at: instant,
          expected_updated_at: instant,
        })
        .strict(),
      reason,
    })
    .strict(),
]);
export function doctorRoutes(db: SupabaseClient) {
  const router = Router(),
    repo = adminRepository(db),
    records = medicalRecords(db);
  const ok = (res: any, data: unknown, status = 200) =>
    res.status(status).json({
      success: true,
      data,
      message: "Operation completed successfully",
    });
  router.use(async (req, res, next) => {
    const user = await authenticate(db, req.headers.authorization),
      rows = await memberships(db, user.id);
    if (!rows.some((m) => m.role === "DOCTOR" && m.doctor_id && m.clinic_id))
      throw new AuthorizationError();
    res.locals.doctor = { user, rows };
    next();
  });
  async function read(
    req: any,
    res: any,
    resource: string,
    query: Record<string, unknown>,
  ) {
    const clinic = uuid.parse(query.clinic_id),
      { user, rows } = res.locals.doctor;
    if (
      !rows.some(
        (m: any) =>
          m.role === "DOCTOR" && m.clinic_id === clinic && m.doctor_id,
      )
    )
      throw new AuthorizationError();
    const { clinic_id, ...params } = query;
    return repo.rpc("doctor_read", {
      p_actor: user.id,
      p_clinic: clinic,
      p_resource: resource,
      p_query: params,
    });
  }
  const clinicOnly = z.object({ clinic_id: uuid }).strict();
  for (const resource of ["me", "schedule", "options"])
    router.get("/" + resource, async (req, res) =>
      ok(res, await read(req, res, resource, clinicOnly.parse(req.query))),
    );
  router.get("/dashboard", async (req, res) => {
    const q = z
      .object({ clinic_id: uuid, from: z.iso.date(), to: z.iso.date() })
      .strict()
      .parse(req.query);
    dashboardSchema.parse({ from: q.from, to: q.to });
    ok(res, await read(req, res, "dashboard", q));
  });
  router.get("/calendar", async (req, res) => {
    const q = z
      .object({ clinic_id: uuid, from: instant, to: instant })
      .strict()
      .parse(req.query);
    calendarSchema.parse({ from: q.from, to: q.to });
    ok(res, await read(req, res, "calendar", q));
  });
  for (const resource of [
    "appointments",
    "patients",
    "notifications",
    "requests",
  ])
    router.get("/" + resource, async (req, res) =>
      ok(res, await read(req, res, resource, list.parse(req.query))),
    );
  router.get("/appointments/:id", async (req, res) =>
    ok(
      res,
      await read(req, res, "appointment", {
        ...clinicOnly.parse(req.query),
        id: uuid.parse(req.params.id),
      }),
    ),
  );
  router.get("/patients/:id", async (req, res) =>
    ok(
      res,
      await read(req, res, "patient", {
        ...clinicOnly.parse(req.query),
        id: uuid.parse(req.params.id),
      }),
    ),
  );
  router.get("/patients/:id/medical-records", async (req, res) =>
    ok(
      res,
      await records.list(
        res.locals.doctor.user.id,
        clinicOnly.parse(req.query).clinic_id,
        uuid.parse(req.params.id),
        true,
      ),
    ),
  );
  router.post("/patients/:id/medical-records", recordUpload, async (req, res) =>
    ok(
      res,
      await records.upload(
        res.locals.doctor.user.id,
        clinicOnly.parse(req.query).clinic_id,
        uuid.parse(req.params.id),
        true,
        req.body,
        req.file,
      ),
      201,
    ),
  );
  router.get("/medical-records/:id/download", async (req, res) =>
    ok(
      res,
      await records.download(
        res.locals.doctor.user.id,
        clinicOnly.parse(req.query).clinic_id,
        uuid.parse(req.params.id),
        "doctor",
      ),
    ),
  );
  router.delete("/medical-records/:id", async (req, res) =>
    ok(
      res,
      await records.remove(
        res.locals.doctor.user.id,
        clinicOnly.parse(req.query).clinic_id,
        uuid.parse(req.params.id),
        true,
      ),
    ),
  );
  router.put("/schedule", async (req, res) => {
    const input = z
      .object({ clinic_id: uuid, schedule: scheduleSchema })
      .strict()
      .parse(req.body);
    ok(
      res,
      await repo.rpc("doctor_schedule_save", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: input.clinic_id,
        p_input: input.schedule,
      }),
    );
  });
  router.get("/queue", async (req, res) => {
    const q = z
      .object({ clinic_id: uuid, day: z.iso.date() })
      .strict()
      .parse(req.query);
    ok(
      res,
      await repo.rpc("clinic_queue", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: q.clinic_id,
        p_day: q.day,
        p_doctor_only: true,
      }),
    );
  });
  router.patch("/appointments/:id/attendance", async (req, res) => {
    const q = z
      .object({
        clinic_id: uuid,
        status: z.enum(["in_consultation", "finished"]),
        expected_updated_at: instant,
      })
      .strict()
      .parse(req.body);
    ok(
      res,
      await repo.rpc("appointment_attendance", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: q.clinic_id,
        p_id: uuid.parse(req.params.id),
        p_status: q.status,
        p_expected: q.expected_updated_at,
        p_doctor_only: true,
      }),
    );
  });
  router.post("/schedule/block", async (req, res) => {
    const q = z
      .object({ clinic_id: uuid, starts_at: instant, ends_at: instant })
      .strict()
      .parse(req.body);
    ok(
      res,
      await repo.rpc("doctor_block_period", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: q.clinic_id,
        p_start: q.starts_at,
        p_end: q.ends_at,
      }),
    );
  });
  router.post("/schedule/copy", async (req, res) => {
    const q = z
      .object({ clinic_id: uuid, source: z.iso.date(), target: z.iso.date() })
      .strict()
      .parse(req.body);
    ok(
      res,
      await repo.rpc("doctor_copy_week", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: q.clinic_id,
        p_source: q.source,
        p_target: q.target,
      }),
    );
  });
  router.post("/schedule-change-requests", async (req, res) => {
    const q = doctorRequestSchema.parse(req.body);
    ok(
      res,
      await repo.rpc("doctor_request", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: q.clinic_id,
        p_kind: q.kind,
        p_payload: q.payload,
        p_reason: q.reason,
      }),
      201,
    );
  });
  router.patch("/appointments/:id/status", async (req, res) => {
    const q = z
      .object({
        clinic_id: uuid,
        status: z.enum(["completed", "no_show"]),
        expected_updated_at: instant,
      })
      .strict()
      .parse(req.body);
    ok(
      res,
      await repo.rpc("doctor_status", {
        p_actor: res.locals.doctor.user.id,
        p_clinic: q.clinic_id,
        p_id: uuid.parse(req.params.id),
        p_input: {
          status: q.status,
          expected_updated_at: q.expected_updated_at,
        },
      }),
    );
  });
  return router;
}
