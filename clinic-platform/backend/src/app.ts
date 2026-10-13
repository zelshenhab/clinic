import multer from "multer";
import express from "express";
import { accountRoutes, type AuthGateway } from "./modules/auth/routes.js";
import type { PatientRepository } from "./modules/patients/repository.js";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import pino from "pino";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import type { Config } from "./config/env.js";
import type { ClinicRepository } from "./modules/clinics/repository.js";
import { AppError, ResourceNotFoundError } from "./common/errors/app-error.js";
import { clinicIdSchema } from "@clinic/shared-contracts";
export function createApp(
  config: Config,
  clinics: ClinicRepository,
  account?: { auth: AuthGateway; patients: PatientRepository },
  catalog?: express.Router,
  admin?: express.Router,
  booking?: express.Router,
  doctor?: express.Router,
) {
  const app = express();
  const log = pino({ enabled: config.NODE_ENV !== "test" });
  app.disable("x-powered-by");
  app.use((req, res, next) => {
    res.locals.requestId = randomUUID();
    res.setHeader("X-Request-ID", res.locals.requestId);
    next();
  });
  app.use(
    helmet(),
    cors({ origin: config.CORS_ORIGINS.split(",").map((s) => s.trim()) }),
  );
  app.use(
    rateLimit({
      windowMs: 60_000,
      limit: 120,
      standardHeaders: "draft-8",
      legacyHeaders: false,
      handler: (_req, res) =>
        res.status(429).json({
          success: false,
          error: {
            code: "RATE_LIMITED",
            message: "Too many requests",
            details: {},
          },
        }),
    }),
  );
  app.use(express.json({ limit: "64kb" }));
  const ok = (res: express.Response, data: unknown) =>
    res.json({
      success: true,
      data,
      message: "Operation completed successfully",
    });
  app.get("/health", (_req, res) => ok(res, { status: "ok" }));
  app.get("/api/v1/clinics", async (_req, res) =>
    ok(res, await clinics.list()),
  );
  app.get("/api/v1/clinics/:clinicId", async (req, res) =>
    ok(res, await clinics.get(clinicIdSchema.parse(req.params.clinicId))),
  );
  app.get("/api/v1/clinics/:clinicId/settings", async (req, res) =>
    ok(res, await clinics.settings(clinicIdSchema.parse(req.params.clinicId))),
  );
  if (doctor) app.use("/api/v1/doctor", doctor);
  if (admin) app.use("/api/v1/admin", admin);
  if (booking) app.use("/api/v1", booking);
  if (catalog) app.use("/api/v1", catalog);
  if (account)
    app.use("/api/v1", accountRoutes(account.auth, account.patients));
  app.use((_req, _res, next) => next(new ResourceNotFoundError()));
  app.use(
    (
      error: unknown,
      req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      const malformed = error instanceof SyntaxError && "body" in error;
      const status =
        error instanceof multer.MulterError
          ? 400
          : error instanceof z.ZodError || malformed
            ? 400
            : error instanceof AppError
              ? error.status
              : 500;
      const code =
        error instanceof multer.MulterError
          ? "UPLOAD_INVALID"
          : error instanceof z.ZodError || malformed
            ? "VALIDATION_ERROR"
            : error instanceof AppError
              ? error.code
              : "INTERNAL_SERVER_ERROR";
      const message =
        status === 400
          ? "Invalid request"
          : error instanceof AppError
            ? error.message
            : "An unexpected error occurred";
      log.error(
        { requestId: res.locals.requestId, method: req.method, status, code },
        "Request failed",
      );
      res.status(status).json({
        success: false,
        error: {
          code,
          message,
          details: {
            requestId: res.locals.requestId,
            ...(error instanceof AppError ? error.details : {}),
            ...(error instanceof z.ZodError
              ? {
                  fields: error.issues.map((i) => ({
                    path: i.path,
                    code: i.code,
                  })),
                }
              : {}),
          },
        },
      });
    },
  );
  return app;
}
