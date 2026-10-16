import type { SupabaseClient } from "@supabase/supabase-js";
import { AppError } from "../../common/errors/app-error.js";
export function adminRepository(db: SupabaseClient) {
  return {
    async rpc(name: string, args: Record<string, unknown>) {
      const { data, error } = await db.rpc(name, args);
      if (error) {
        const code = error.code;
        const domain = [
          "SLOT_UNAVAILABLE",
          "SCHEDULE_CONFLICT",
          "INVALID_TRANSITION",
          "STALE_APPOINTMENT",
          "FORBIDDEN",
          "NOT_FOUND",
          "VALIDATION_ERROR",
          "POLICY_CUTOFF",
          "SLOT_ALREADY_AVAILABLE",
        ].find((x) => error.message === x);
        const invalid = ["23502", "23503", "23514", "22P02", "22007"].includes(
          code,
        );
        const status = invalid
          ? 400
          : code === "23P01" ||
              code === "23505" ||
              domain === "SLOT_UNAVAILABLE" ||
              domain === "SCHEDULE_CONFLICT" ||
              domain === "STALE_APPOINTMENT" ||
              domain === "POLICY_CUTOFF" ||
              domain === "SLOT_ALREADY_AVAILABLE"
            ? 409
            : domain === "FORBIDDEN"
              ? 403
              : domain === "NOT_FOUND"
                ? 404
                : domain === "INVALID_TRANSITION" ||
                    domain === "VALIDATION_ERROR"
                  ? 400
                  : 503;
        throw new AppError(
          status,
          domain ??
            (invalid
              ? "VALIDATION_ERROR"
              : status === 409
                ? "CONFLICT"
                : "DATABASE_UNAVAILABLE"),
          "Operation could not be completed",
          domain === "SCHEDULE_CONFLICT"
            ? { appointmentIds: parseConflictIds(error.details) }
            : {},
        );
      }
      return data;
    },
    async clinics(ids?: string[]) {
      let query = db
        .from("clinics")
        .select("id,name,address,description,timezone,phone,active,logo_url")
        .order("created_at");
      if (ids) query = query.in("id", ids);
      const { data, error } = await query;
      if (error)
        throw new AppError(503, "DATABASE_UNAVAILABLE", "Clinics unavailable");
      return data ?? [];
    },
  };
}

function parseConflictIds(value: string) {
  try {
    const ids = JSON.parse(value);
    return Array.isArray(ids)
      ? ids
          .filter((id) => typeof id === "string" && /^[0-9a-f-]{36}$/.test(id))
          .slice(0, 100)
      : [];
  } catch {
    return [];
  }
}
