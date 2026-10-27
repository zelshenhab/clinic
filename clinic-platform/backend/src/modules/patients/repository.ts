import type { SupabaseClient } from "@supabase/supabase-js";
import {
  AppError,
  ResourceNotFoundError,
} from "../../common/errors/app-error.js";
export interface ProfileInput {
  full_name: string;
  email?: string | null;
  language?: "ru" | "en";
}
export interface FamilyMemberInput {
  full_name: string;
  relationship: "child" | "spouse" | "parent" | "sibling" | "other";
  date_of_birth?: string | null;
}
export const FAMILY_MEMBER_LIMIT = 10;
export interface PatientRepository {
  profile(userId: string): Promise<unknown>;
  update(userId: string, input: ProfileInput): Promise<unknown>;
  appointments(userId: string, clinicId: string): Promise<unknown[]>;
  notifications(userId: string, clinicId: string): Promise<unknown[]>;
  familyMembers(userId: string): Promise<unknown[]>;
  addFamilyMember(userId: string, input: FamilyMemberInput): Promise<unknown>;
  updateFamilyMember(
    userId: string,
    id: string,
    input: FamilyMemberInput,
  ): Promise<unknown>;
  removeFamilyMember(userId: string, id: string): Promise<void>;
}
const familyColumns = "id,full_name,relationship,date_of_birth,created_at";
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
  async function familyMembers(owner: string) {
    const { data, error } = await db
      .from("family_members")
      .select(familyColumns)
      .eq("owner_id", owner)
      .eq("active", true)
      .order("created_at")
      .limit(FAMILY_MEMBER_LIMIT);
    if (error)
      throw new AppError(
        503,
        "DATABASE_UNAVAILABLE",
        "Family members temporarily unavailable",
      );
    return data ?? [];
  }
  return {
    profile,
    familyMembers,
    addFamilyMember: async (owner, input) => {
      if ((await profile(owner)) == null)
        throw new AppError(403, "FORBIDDEN", "Complete your profile first");
      if ((await familyMembers(owner)).length >= FAMILY_MEMBER_LIMIT)
        throw new AppError(
          409,
          "FAMILY_LIMIT_REACHED",
          "Family member limit reached",
        );
      const { data, error } = await db
        .from("family_members")
        .insert({ owner_id: owner, ...input })
        .select(familyColumns)
        .single();
      if (error)
        throw new AppError(
          503,
          "DATABASE_UNAVAILABLE",
          "Family member could not be saved",
        );
      return data;
    },
    updateFamilyMember: async (owner, id, input) => {
      const { data, error } = await db
        .from("family_members")
        .update(input)
        .eq("id", id)
        .eq("owner_id", owner)
        .eq("active", true)
        .select(familyColumns)
        .maybeSingle();
      if (error)
        throw new AppError(
          503,
          "DATABASE_UNAVAILABLE",
          "Family member could not be saved",
        );
      if (!data) throw new ResourceNotFoundError();
      return data;
    },
    // Soft removal keeps past appointments attributed to the right person.
    removeFamilyMember: async (owner, id) => {
      const { data, error } = await db
        .from("family_members")
        .update({ active: false })
        .eq("id", id)
        .eq("owner_id", owner)
        .eq("active", true)
        .select("id")
        .maybeSingle();
      if (error)
        throw new AppError(
          503,
          "DATABASE_UNAVAILABLE",
          "Family member could not be removed",
        );
      if (!data) throw new ResourceNotFoundError();
    },
    notifications: async (userId, clinicId) => {
      const { data, error } = await db
        .from("notifications")
        .select("id,clinic_id,title,body,created_at,read_at,appointment_id,kind,context")
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
        .from("admin_appointments")
        .select("id,clinic_id,doctor_id,service_id,starts_at,ends_at,status,updated_at,doctor_name,service_name,attendance_status,family_member_id,patient_name")
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
