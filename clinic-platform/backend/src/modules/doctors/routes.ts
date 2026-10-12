import { Router } from "express";
import type { SupabaseClient } from "@supabase/supabase-js";
import { clinicIdSchema } from "@clinic/shared-contracts";
import { catalogQuerySchema } from "@clinic/shared-contracts/catalog";
import { CatalogService } from "../catalog/service.js";
import { catalogRepository } from "../catalog/repository.js";
import { clinicRepository } from "../clinics/repository.js";
import type { Kind } from "../catalog/types.js";
export function catalogRoutes(db: SupabaseClient) {
  return catalogController(
    new CatalogService(catalogRepository(db), clinicRepository(db)),
  );
}
export function catalogController(service: CatalogService) {
  const router = Router();
  const ok = (res: import("express").Response, data: unknown) =>
    res.json({
      success: true,
      data,
      message: "Operation completed successfully",
    });
  router.get("/clinics/:clinicId/booking-context", async (req, res) =>
    ok(
      res,
      await service.bookingContext(
        clinicIdSchema.parse(req.params.clinicId),
        catalogQuerySchema.parse(req.query),
      ),
    ),
  );
  router.get("/clinics/:clinicId/home", async (req, res) =>
    ok(
      res,
      await service.home(
        clinicIdSchema.parse(req.params.clinicId),
        catalogQuerySchema.parse(req.query),
      ),
    ),
  );
  for (const kind of [
    "doctors",
    "specialties",
    "services",
    "promotions",
  ] as Kind[]) {
    router.get(`/clinics/:clinicId/${kind}`, async (req, res) =>
      ok(
        res,
        await service.list(
          kind,
          clinicIdSchema.parse(req.params.clinicId),
          catalogQuerySchema.parse(req.query),
        ),
      ),
    );
    if (kind !== "promotions")
      router.get(`/clinics/:clinicId/${kind}/:recordId`, async (req, res) =>
        ok(
          res,
          await service.detail(
            kind,
            clinicIdSchema.parse(req.params.clinicId),
            clinicIdSchema.parse(req.params.recordId),
            catalogQuerySchema.parse(req.query),
          ),
        ),
      );
  }
  return router;
}
