import type { SupabaseClient } from "@supabase/supabase-js";
import { AppError, AuthorizationError } from "../../common/errors/app-error.js";
import { adminRepository } from "./repository.js";
import type { StaffAccess } from "./permissions.js";
export class AdminService {
  private repo;
  constructor(private db: SupabaseClient) {
    this.repo = adminRepository(db);
  }
  list(actor: string, clinic: string, resource: string, query: unknown) {
    return this.repo.rpc("admin_list", {
      p_actor: actor,
      p_clinic: clinic,
      p_resource: resource,
      p_query: query,
    });
  }
  detail(actor: string, clinic: string, resource: string, id: string) {
    return this.repo.rpc("admin_detail", {
      p_actor: actor,
      p_clinic: clinic,
      p_resource: resource,
      p_id: id,
    });
  }
  dashboard(
    actor: string,
    clinic: string,
    query: { from: string; to: string },
  ) {
    return this.repo.rpc("admin_dashboard", {
      p_actor: actor,
      p_clinic: clinic,
      p_from: query.from,
      p_to: query.to,
    });
  }
  calendar(
    actor: string,
    clinic: string,
    q: { from: string; to: string; doctor_id?: string },
  ) {
    return this.repo.rpc("admin_calendar", {
      p_actor: actor,
      p_clinic: clinic,
      p_from: q.from,
      p_to: q.to,
      p_doctor: q.doctor_id ?? null,
    });
  }
  options(actor: string, clinic: string) {
    return this.repo.rpc("admin_options", { p_actor: actor, p_clinic: clinic });
  }
  write(
    access: StaffAccess,
    clinic: string,
    resource: string,
    id: string | null,
    input: Record<string, unknown>,
  ) {
    if (input.doctor_id && access.role !== "SUPER_ADMIN")
      throw new AuthorizationError();
    if (
      resource === "promotions" &&
      input.starts_at &&
      input.ends_at &&
      Date.parse(String(input.ends_at)) <= Date.parse(String(input.starts_at))
    )
      throw new AppError(400, "VALIDATION_ERROR", "Invalid promotion period");
    return this.repo.rpc("admin_write", {
      p_actor: access.userId,
      p_clinic: clinic,
      p_resource: resource,
      p_id: id,
      p_input: input,
    });
  }
  availability(
    actor: string,
    clinic: string,
    q: { doctor_id: string; service_id: string; date: string },
  ) {
    return this.repo.rpc("admin_availability", {
      p_actor: actor,
      p_clinic: clinic,
      p_doctor: q.doctor_id,
      p_service: q.service_id,
      p_date: q.date,
    });
  }
  book(actor: string, clinic: string, input: unknown) {
    return this.repo.rpc("admin_book", {
      p_actor: actor,
      p_clinic: clinic,
      p_input: input,
    });
  }
  appointment(
    access: StaffAccess,
    clinic: string,
    id: string,
    input: { starts_at?: string; status?: string },
  ) {
    if (
      access.role === "DOCTOR" &&
      (input.starts_at ||
        !["completed", "no_show"].includes(input.status ?? ""))
    )
      throw new AuthorizationError();
    return this.repo.rpc("admin_appointment_change", {
      p_actor: access.userId,
      p_clinic: clinic,
      p_id: id,
      p_input: input,
    });
  }
  schedules(actor: string, clinic: string, doctor: string, input?: unknown) {
    return this.repo.rpc(input ? "admin_schedule_save" : "admin_schedule_get", {
      p_actor: actor,
      p_clinic: clinic,
      p_doctor: doctor,
      ...(input ? { p_input: input } : {}),
    });
  }
  settings(actor: string, clinic: string, input?: unknown) {
    return this.repo.rpc("admin_settings", {
      p_actor: actor,
      p_clinic: clinic,
      ...(input ? { p_input: input } : {}),
    });
  }
  async identity(email?: string, userId?: string) {
    if (userId) return userId;
    if (!email)
      throw new AppError(400, "VALIDATION_ERROR", "Identity required");
    const { data, error } = await this.db.auth.admin.inviteUserByEmail(
      email,
      process.env.DASHBOARD_URL
        ? { redirectTo: process.env.DASHBOARD_URL + "/auth/password" }
        : undefined,
    );
    if (error || !data.user)
      throw new AppError(
        503,
        "INVITATION_FAILED",
        "Invitation could not be completed",
      );
    return data.user.id;
  }
  async patient(
    actor: string,
    clinic: string,
    input: { user_id?: string; email?: string },
  ) {
    const user = await this.identity(input.email, input.user_id);
    return this.repo.rpc("admin_patient_link", {
      p_actor: actor,
      p_clinic: clinic,
      p_user: user,
      p_input: input,
    });
  }
  async staff(
    actor: string,
    clinic: string,
    input: { user_id?: string; email?: string },
  ) {
    const user = await this.identity(input.email, input.user_id);
    if (actor === user) throw new AuthorizationError();
    return this.repo.rpc("admin_staff_save", {
      p_actor: actor,
      p_clinic: clinic,
      p_user: user,
      p_input: input,
    });
  }
}
