import { Router } from "express";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { authenticate } from "../../common/middleware/auth.js";
import { adminRepository } from "../admin/repository.js";
import { uuid, availabilitySchema, bookSchema } from "../admin/validation.js";
export function bookingRoutes(db: SupabaseClient) {
  const router = Router(),
    repo = adminRepository(db),
    base = "/clinics/:clinicId";
  router.use(base + "/booking", async (req, res, next) => {
    const user = await authenticate(db, req.headers.authorization);
    res.locals.actor = user.id;
    res.locals.clinic = uuid.parse(req.params.clinicId);
    next();
  });
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
    const input = bookSchema.omit({ patient_id: true }).parse(req.body);
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
