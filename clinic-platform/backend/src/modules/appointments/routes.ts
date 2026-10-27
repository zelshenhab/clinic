import { Router } from "express";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { authenticate } from "../../common/middleware/auth.js";
import { adminRepository } from "../admin/repository.js";
import { uuid, availabilitySchema, bookSchema } from "../admin/validation.js";
import { medicalRecords } from "../medical_records/service.js";
export function bookingRoutes(db: SupabaseClient) {
  const router = Router(),
    repo = adminRepository(db),
    records = medicalRecords(db),
    base = "/clinics/:clinicId";
  router.get(base + "/availability", async (req, res) => {
    const clinic = uuid.parse(req.params.clinicId),
      q = availabilitySchema.parse(req.query);
    res.json({
      success: true,
      data: await repo.rpc("public_availability", {
        p_clinic: clinic,
        p_doctor: q.doctor_id,
        p_service: q.service_id,
        p_date: q.date,
      }),
      message: "Available slots",
    });
  });
  router.get(base + "/booking-policy", async (req, res) =>
    res.json({
      success: true,
      data: await repo.rpc("booking_policy", {
        p_clinic: uuid.parse(req.params.clinicId),
      }),
    }),
  );
  router.get(base + "/next-available", async (req, res) => {
    const q = z
      .object({
        specialty_id: uuid.optional(),
        service_id: uuid.optional(),
        from: z.iso.date().optional(),
        limit: z.coerce.number().int().min(1).max(20).default(10),
      })
      .strict()
      .parse(req.query);
    res.json({
      success: true,
      data: await repo.rpc("next_available", {
        p_clinic: uuid.parse(req.params.clinicId),
        p_specialty: q.specialty_id ?? null,
        p_service: q.service_id ?? null,
        p_from: q.from ?? null,
        p_limit: q.limit,
      }),
    });
  });
  router.use(
    [base + "/booking", base + "/medical-records"],
    async (req, res, next) => {
      const user = await authenticate(db, req.headers.authorization);
      res.locals.actor = user.id;
      res.locals.clinic = uuid.parse(req.params.clinicId);
      next();
    },
  );
  router.get(base + "/medical-records", async (_req, res) =>
    res.json({
      success: true,
      data: await records.patientList(res.locals.actor, res.locals.clinic),
    }),
  );
  router.get(base + "/medical-records/:id/download", async (req, res) =>
    res.json({
      success: true,
      data: await records.download(
        res.locals.actor,
        res.locals.clinic,
        uuid.parse(req.params.id),
        "patient",
      ),
    }),
  );
  router.get(base + "/booking/availability", async (req, res) => {
    const q = availabilitySchema.parse(req.query);
    res.json({
      success: true,
      data: await repo.rpc("patient_availability", {
        p_actor: res.locals.actor,
        p_clinic: res.locals.clinic,
        p_doctor: q.doctor_id,
        p_service: q.service_id,
        p_date: q.date,
      }),
      message: "Available slots",
    });
  });
  router.post(base + "/booking/appointments", async (req, res) => {
    const input = bookSchema
      .omit({ patient_id: true })
      .extend({ family_member_id: uuid.nullable().optional() })
      .parse(req.body);
    res.status(201).json({
      success: true,
      data: await repo.rpc("patient_book", {
        p_actor: res.locals.actor,
        p_clinic: res.locals.clinic,
        p_input: input,
      }),
      message: "Appointment booked",
    });
  });
  router.get(base + "/booking/waitlist", async (_req, res) =>
    res.json({
      success: true,
      data: await repo.rpc("patient_waitlist", {
        p_actor: res.locals.actor,
        p_clinic: res.locals.clinic,
      }),
    }),
  );
  router.post(base + "/booking/waitlist", async (req, res) => {
    const q = z
      .object({ doctor_id: uuid, service_id: uuid, day: z.iso.date() })
      .strict()
      .parse(req.body);
    res
      .status(201)
      .json({
        success: true,
        data: await repo.rpc("patient_waitlist", {
          p_actor: res.locals.actor,
          p_clinic: res.locals.clinic,
          p_input: q,
        }),
      });
  });
  router.delete(base + "/booking/waitlist/:id", async (req, res) =>
    res.json({
      success: true,
      data: await repo.rpc("patient_waitlist", {
        p_actor: res.locals.actor,
        p_clinic: res.locals.clinic,
        p_input: { id: uuid.parse(req.params.id) },
      }),
    }),
  );
  router.patch(base + "/booking/notifications/:id", async (req, res) => {
    z.object({ read: z.literal(true) })
      .strict()
      .parse(req.body);
    res.json({
      success: true,
      data: await repo.rpc("patient_read_notification", {
        p_actor: res.locals.actor,
        p_clinic: res.locals.clinic,
        p_id: uuid.parse(req.params.id),
      }),
    });
  });
  router.post(
    base + "/booking/appointments/:id/reschedule",
    async (req, res) => {
      const q = z
        .object({
          starts_at: z.iso.datetime({ offset: true }),
          expected_updated_at: z.iso.datetime({ offset: true }),
        })
        .strict()
        .parse(req.body);
      res.json({
        success: true,
        data: await repo.rpc("patient_change", {
          p_actor: res.locals.actor,
          p_clinic: res.locals.clinic,
          p_id: uuid.parse(req.params.id),
          p_expected: q.expected_updated_at,
          p_start: q.starts_at,
        }),
      });
    },
  );
  router.patch(base + "/booking/appointments/:id", async (req, res) => {
    const input = z
      .object({
        status: z.literal("cancelled"),
        expected_updated_at: z.iso.datetime({ offset: true }),
      })
      .strict()
      .parse(req.body);
    res.json({
      success: true,
      data: await repo.rpc("patient_cancel", {
        p_actor: res.locals.actor,
        p_clinic: res.locals.clinic,
        p_id: uuid.parse(req.params.id),
        p_expected: input.expected_updated_at,
      }),
      message: "Appointment cancelled",
    });
  });
  return router;
}
