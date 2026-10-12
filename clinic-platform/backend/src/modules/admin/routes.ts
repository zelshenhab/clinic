import { Router } from "express";
import type { Request, Response, NextFunction } from "express";
import type { SupabaseClient } from "@supabase/supabase-js";
import { authenticate } from "../../common/middleware/auth.js";
import { AuthorizationError, AppError } from "../../common/errors/app-error.js";
import { memberships, authorize, type Membership } from "./permissions.js";
import { adminRepository } from "./repository.js";
import { AdminService } from "./service.js";
import { catalogUpload, uploadArtwork } from "./uploads.js";
import { z } from "zod";
import {
  uuid,
  calendarSchema,
  listSchema,
  resourceSchemas,
  type Resource,
  bookSchema,
  changeSchema,
  availabilitySchema,
  dashboardSchema,
  scheduleSchema,
  settingsSchema,
  patientSchema,
  staffSchema,
} from "./validation.js";
export function adminRoutes(db: SupabaseClient) {
  const router = Router(),
    repo = adminRepository(db),
    service = new AdminService(db);
  const ok = (res: Response, data: unknown, status = 200) =>
    res.status(status).json({
      success: true,
      data,
      message: "Operation completed successfully",
    });
  const guard =
    (operation: string) =>
    (req: Request, res: Response, next: NextFunction) => {
      const clinic = uuid.parse(req.params.clinicId),
        { user, rows } = res.locals.staff;
      res.locals.access = authorize(rows, user.id, clinic, operation);
      res.locals.clinic = clinic;
      next();
    };
  router.use(async (req, res, next) => {
    const user = await authenticate(db, req.headers.authorization);
    const rows = await memberships(db, user.id);
    if (!rows.length) throw new AuthorizationError();
    res.locals.staff = { user, rows };
    next();
  });
  router.get("/me", async (_req, res) => {
    const { user, rows } = res.locals.staff;
    ok(res, { id: user.id, email: user.email, memberships: rows });
  });
  router.get("/clinics", async (_req, res) => {
    const rows = res.locals.staff.rows as Membership[];
    const ids = rows.some((m) => m.role === "SUPER_ADMIN")
      ? undefined
      : [...new Set(rows.flatMap((m) => (m.clinic_id ? [m.clinic_id] : [])))];
    ok(res, await repo.clinics(ids));
  });
  const superGuard = (_req: Request, res: Response, next: NextFunction) => {
    authorize(res.locals.staff.rows, res.locals.staff.user.id, "", "staff");
    next();
  };
  router.get("/analytics", superGuard, async (req, res) => {
    const q = dashboardSchema.parse(req.query);
    ok(
      res,
      await repo.rpc("admin_analytics", {
        p_actor: res.locals.staff.user.id,
        p_from: q.from,
        p_to: q.to,
      }),
    );
  });
  router.get("/system", superGuard, async (_req, res) =>
    ok(
      res,
      await repo.rpc("admin_system", { p_actor: res.locals.staff.user.id }),
    ),
  );
  router.patch("/system", superGuard, async (req, res) =>
    ok(
      res,
      await repo.rpc("admin_system", {
        p_actor: res.locals.staff.user.id,
        p_input: z
          .object({
            booking_horizon_days: z.number().int().min(7).max(180),
            booking_enabled: z.boolean(),
          })
          .strict()
          .parse(req.body),
      }),
    ),
  );
  const base = "/clinics/:clinicId";
  router.get(base + "/dashboard", guard("overview"), async (req, res) =>
    ok(
      res,
      await service.dashboard(
        res.locals.access.userId,
        res.locals.clinic,
        dashboardSchema.parse(req.query),
      ),
    ),
  );
  router.get(base + "/calendar", guard("appointments"), async (req, res) =>
    ok(
      res,
      await service.calendar(
        res.locals.access.userId,
        res.locals.clinic,
        calendarSchema.parse(req.query),
      ),
    ),
  );
  router.get(base + "/catalog-options", guard("catalog"), async (_req, res) =>
    ok(
      res,
      await repo.rpc("admin_catalog_options", {
        p_actor: res.locals.access.userId,
        p_clinic: res.locals.clinic,
      }),
    ),
  );
  router.get(
    base + "/schedule-options",
    guard("schedules"),
    async (_req, res) =>
      ok(
        res,
        await repo.rpc("admin_schedule_options", {
          p_actor: res.locals.access.userId,
          p_clinic: res.locals.clinic,
        }),
      ),
  );
  router.get(
    base + "/filter-options",
    guard("appointments"),
    async (_req, res) =>
      ok(
        res,
        await repo.rpc("admin_filter_options", {
          p_actor: res.locals.access.userId,
          p_clinic: res.locals.clinic,
        }),
      ),
  );
  router.get(base + "/options", guard("appointments"), async (_req, res) =>
    ok(res, await service.options(res.locals.access.userId, res.locals.clinic)),
  );
  router.get(base + "/availability", guard("appointments"), async (req, res) =>
    ok(
      res,
      await service.availability(
        res.locals.access.userId,
        res.locals.clinic,
        availabilitySchema.parse(req.query),
      ),
    ),
  );
  router.get(base + "/appointments", guard("appointments"), async (req, res) =>
    ok(
      res,
      await service.list(
        res.locals.access.userId,
        res.locals.clinic,
        "appointments",
        listSchema.parse(req.query),
      ),
    ),
  );
  router.get(
    base + "/appointments/:id",
    guard("appointments"),
    async (req, res) =>
      ok(
        res,
        await service.detail(
          res.locals.access.userId,
          res.locals.clinic,
          "appointments",
          uuid.parse(req.params.id),
        ),
      ),
  );
  router.post(base + "/appointments", guard("book"), async (req, res) =>
    ok(
      res,
      await service.book(
        res.locals.access.userId,
        res.locals.clinic,
        bookSchema.parse(req.body),
      ),
      201,
    ),
  );
  router.patch(base + "/appointments/:id", guard("status"), async (req, res) =>
    ok(
      res,
      await service.appointment(
        res.locals.access,
        res.locals.clinic,
        uuid.parse(req.params.id),
        changeSchema.parse(req.body),
      ),
    ),
  );
  for (const resource of Object.keys(resourceSchemas) as Resource[]) {
    router.get(base + "/" + resource, guard("catalog"), async (req, res) =>
      ok(
        res,
        await service.list(
          res.locals.access.userId,
          res.locals.clinic,
          resource,
          listSchema.parse(req.query),
        ),
      ),
    );
    router.get(
      base + "/" + resource + "/:id",
      guard("catalog"),
      async (req, res) =>
        ok(
          res,
          await service.detail(
            res.locals.access.userId,
            res.locals.clinic,
            resource,
            uuid.parse(req.params.id),
          ),
        ),
    );
    router.post(base + "/" + resource, guard("catalog"), async (req, res) =>
      ok(
        res,
        await service.write(
          res.locals.access,
          res.locals.clinic,
          resource,
          null,
          resourceSchemas[resource].parse(req.body),
        ),
        201,
      ),
    );
    router.patch(
      base + "/" + resource + "/:id",
      guard("catalog"),
      async (req, res) => {
        const input = resourceSchemas[resource].partial().parse(req.body);
        if (!Object.keys(input).length)
          throw new AppError(400, "VALIDATION_ERROR", "Fields required");
        ok(
          res,
          await service.write(
            res.locals.access,
            res.locals.clinic,
            resource,
            uuid.parse(req.params.id),
            input,
          ),
        );
      },
    );
  }
  router.get(base + "/patients", guard("patients"), async (req, res) =>
    ok(
      res,
      await service.list(
        res.locals.access.userId,
        res.locals.clinic,
        "patients",
        listSchema.parse(req.query),
      ),
    ),
  );
  router.get(base + "/patients/:id", guard("patients"), async (req, res) =>
    ok(
      res,
      await service.detail(
        res.locals.access.userId,
        res.locals.clinic,
        "patients",
        uuid.parse(req.params.id),
      ),
    ),
  );
  router.post(base + "/patients", guard("patients"), async (req, res) =>
    ok(
      res,
      await service.patient(
        res.locals.access.userId,
        res.locals.clinic,
        patientSchema.parse(req.body),
      ),
      201,
    ),
  );
  router.get(base + "/schedules", guard("schedules"), async (req, res) =>
    ok(
      res,
      await service.list(
        res.locals.access.userId,
        res.locals.clinic,
        "schedules",
        listSchema.parse(req.query),
      ),
    ),
  );
  router.get(
    base + "/doctors/:id/schedules",
    guard("schedules"),
    async (req, res) =>
      ok(
        res,
        await service.schedules(
          res.locals.access.userId,
          res.locals.clinic,
          uuid.parse(req.params.id),
        ),
      ),
  );
  router.put(
    base + "/doctors/:id/schedules",
    guard("scheduleWrite"),
    async (req, res) =>
      ok(
        res,
        await service.schedules(
          res.locals.access.userId,
          res.locals.clinic,
          uuid.parse(req.params.id),
          scheduleSchema.parse(req.body),
        ),
      ),
  );
  router.get(base + "/settings", guard("settings"), async (_req, res) =>
    ok(
      res,
      await service.settings(res.locals.access.userId, res.locals.clinic),
    ),
  );
  router.patch(base + "/settings", guard("settings"), async (req, res) =>
    ok(
      res,
      await service.settings(
        res.locals.access.userId,
        res.locals.clinic,
        settingsSchema.parse(req.body),
      ),
    ),
  );
  router.get(base + "/staff", guard("staff"), async (req, res) =>
    ok(
      res,
      await service.list(
        res.locals.access.userId,
        res.locals.clinic,
        "staff",
        listSchema.parse(req.query),
      ),
    ),
  );
  router.post(base + "/staff", guard("staff"), async (req, res) =>
    ok(
      res,
      await service.staff(
        res.locals.access.userId,
        res.locals.clinic,
        staffSchema.parse(req.body),
      ),
      201,
    ),
  );
  router.post(
    base + "/uploads",
    guard("upload"),
    catalogUpload,
    async (req, res) =>
      ok(
        res,
        await uploadArtwork(
          db,
          res.locals.access.userId,
          res.locals.clinic,
          req.file,
        ),
        201,
      ),
  );
  return router;
}
