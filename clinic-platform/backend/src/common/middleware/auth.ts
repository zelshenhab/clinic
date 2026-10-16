import { createHash } from "node:crypto";
import { inFlight } from "../async/in-flight.js";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  AuthenticationError,
  AuthorizationError,
  AppError,
} from "../errors/app-error.js";
export type StaffRole =
  "SUPER_ADMIN" | "CLINIC_ADMIN" | "RECEPTIONIST" | "DOCTOR";
export async function authenticate(db: SupabaseClient, header?: string) {
  if (!header?.startsWith("Bearer ")) throw new AuthenticationError();
  const token = header.slice(7);
  const { data, error } = await inFlight(
    db,
    "auth:" + createHash("sha256").update(token).digest("hex"),
    () => db.auth.getUser(token),
  );
  if (
    error &&
    (error.status === 0 ||
      (error.status ?? 0) >= 500 ||
      error.name === "AuthRetryableFetchError")
  )
    throw new AppError(
      503,
      "AUTH_UNAVAILABLE",
      "Authentication is temporarily unavailable",
    );
  if (error || !data.user) throw new AuthenticationError();
  return data.user;
}
export async function requireClinicRole(
  db: SupabaseClient,
  userId: string,
  clinicId: string,
  allowed: StaffRole[],
) {
  const { data, error } = await db
    .from("staff_memberships")
    .select("role,clinic_id")
    .eq("user_id", userId)
    .eq("active", true);
  if (error)
    throw new AppError(
      503,
      "AUTHORIZATION_UNAVAILABLE",
      "Authorization is temporarily unavailable",
    );
  if (
    !data?.some(
      (m) =>
        m.role === "SUPER_ADMIN" ||
        (m.clinic_id === clinicId && allowed.includes(m.role as StaffRole)),
    )
  )
    throw new AuthorizationError();
}
