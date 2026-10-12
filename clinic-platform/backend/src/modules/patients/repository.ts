import type { SupabaseClient } from "@supabase/supabase-js";
import { AppError } from "../../common/errors/app-error.js";
export interface ProfileInput {
  full_name: string;
  email?: string | null;
  language?: "ru" | "en";
}
export interface PatientRepository {
  profile(userId: string): Promise<unknown>;
  update(userId: string, input: ProfileInput): Promise<unknown>;
  appointments(userId: string, clinicId: string): Promise<unknown[]>;
  notifications(userId: string, clinicId: string): Promise<unknown[]>;
}
export function patientRepository(db: SupabaseClient): PatientRepository {
  async function profile(id: string) {
    const { data, error } = await db
      .from("patient_profiles")
      .select(
        "id,full_name,email,date_of_birth,language,notification_preferences",
      )
      .eq("id", id)
      .maybeSingle();
    if (error)
      throw new AppError(
        503,
        "DATABASE_UNAVAILABLE",
        "Profile temporarily unavailable",
      );
    return data;
  }
  return {
    profile,
    notifications: async (userId, clinicId) => {
      const { data, error } = await db
        .from("notifications")
        .select("id,clinic_id,title,body,created_at,read_at")
        .eq("user_id", userId)
        .eq("clinic_id", clinicId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error)
        throw new AppError(
          503,
          "DATABASE_UNAVAILABLE",
          "Notifications temporarily unavailable",
        );
      return data ?? [];
    },
    update: async (id, input) => {
      const { data, error } = await db
        .from("patient_profiles")
        .upsert({ id, ...input }, { onConflict: "id" })
        .select(
          "id,full_name,email,date_of_birth,language,notification_preferences",
        )
        .single();
      if (error)
        throw new AppError(
          503,
          "DATABASE_UNAVAILABLE",
          "Profile could not be saved",
        );
      return data;
    },
    appointments: async (userId, clinicId) => {
      const { data, error } = await db
        .from("appointments")
        .select("id,clinic_id,doctor_id,service_id,starts_at,ends_at,status")
        .eq("patient_id", userId)
        .eq("clinic_id", clinicId)
        .order("starts_at");
      if (error)
        throw new AppError(
          503,
          "DATABASE_UNAVAILABLE",
          "Appointments temporarily unavailable",
        );
      return data ?? [];
    },
  };
}
