import { inFlight } from "../../common/async/in-flight.js";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AppError, AuthorizationError } from "../../common/errors/app-error.js";
import type { StaffRole } from "../../common/middleware/auth.js";
export interface Membership {
  id: string;
  role: StaffRole;
  clinic_id: string | null;
  doctor_id: string | null;
}
export interface StaffAccess {
  userId: string;
  role: StaffRole;
  doctorId?: string;
}
export const permissions: Record<string, StaffRole[]> = {
  overview: ["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"],
  appointments: ["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"],
  book: ["CLINIC_ADMIN", "RECEPTIONIST"],
  status: ["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"],
  patients: ["CLINIC_ADMIN", "RECEPTIONIST"],
  catalog: ["CLINIC_ADMIN"],
  schedules: ["CLINIC_ADMIN", "DOCTOR"],
  scheduleWrite: ["CLINIC_ADMIN"],
  settings: ["CLINIC_ADMIN"],
  staff: [],
  upload: ["CLINIC_ADMIN"],
  records: ["CLINIC_ADMIN", "RECEPTIONIST"],
};
export async function memberships(
  db: SupabaseClient,
  userId: string,
): Promise<Membership[]> {
  const { data, error } = await inFlight(
    db,
    "memberships:" + userId,
    async () =>
      await db
        .from("staff_memberships")
        .select("id,role,clinic_id,doctor_id")
        .eq("user_id", userId)
        .eq("active", true),
  );
  if (error)
    throw new AppError(
      503,
      "AUTHORIZATION_UNAVAILABLE",
      "Authorization unavailable",
    );
  return (data as Membership[]) ?? [];
}
export function authorize(
  rows: Membership[],
  userId: string,
  clinicId: string,
  operation: string,
): StaffAccess {
  if (rows.some((row) => row.role === "SUPER_ADMIN" && row.clinic_id === null))
    return { userId, role: "SUPER_ADMIN" };
  const allowed = permissions[operation];
  if (!allowed) throw new AuthorizationError();
  const matches = rows.filter(
    (row) => row.clinic_id === clinicId && allowed.includes(row.role),
  );
  const row =
    matches.find((row) => row.role === "CLINIC_ADMIN") ??
    matches.find((row) => row.role === "RECEPTIONIST") ??
    matches[0];
  if (!row || (row.role === "DOCTOR" && !row.doctor_id))
    throw new AuthorizationError();
  return {
    userId,
    role: row.role,
    ...(row.doctor_id ? { doctorId: row.doctor_id } : {}),
  };
}
