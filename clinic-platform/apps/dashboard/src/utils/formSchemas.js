import { z } from "zod";
const localized = z.object({ ru: z.string(), en: z.string() }),
  name = z.object({
    ru: z.string().trim().min(2),
    en: z.string().trim().min(2),
  }),
  ids = z.array(z.uuid()),
  order = z.number().int().min(0).max(10000);
export const catalogSchemas = {
  doctors: z.object({
    doctor_id: z.string().optional(),
    name,
    description: localized,
    professional_title: localized,
    experience_years: z.number().int().min(0).max(80),
    education: localized,
    biography: localized,
    qualifications: localized,
    languages: z.array(z.enum(["ru", "en"])),
    active: z.boolean(),
    featured: z.boolean(),
    sort_order: order,
    specialty_ids: ids,
    service_ids: ids,
    photo_url: z.url().nullable(),
  }),
  specialties: z.object({
    name,
    description: localized,
    icon: z.string().min(1),
    active: z.boolean(),
    sort_order: order,
    doctor_ids: ids,
  }),
  services: z.object({
    name,
    description: localized,
    specialty_id: z.uuid(),
    duration_minutes: z.number().int().min(5).max(480),
    price_rub: z.number().min(0).max(1000000),
    category_key: z.string().regex(/^[a-z_]{1,40}$/),
    category: name,
    active: z.boolean(),
    featured: z.boolean(),
    sort_order: order,
    doctor_ids: ids,
  }),
  promotions: z
    .object({
      title: name,
      description: localized,
      image_url: z.url().nullable(),
      starts_at: z.string().min(1),
      ends_at: z.string().min(1),
      action_kind: z.string().nullable(),
      active: z.boolean(),
      sort_order: order,
    })
    .refine((v) => v.ends_at > v.starts_at, { path: ["ends_at"] }),
};
export function catalogDefaults(resource, row) {
  const blank = { ru: "", en: "" };
  const value = { ...row };
  if (resource === "doctors")
    return {
      name: value.name || blank,
      description: value.description || blank,
      professional_title: value.professional_title || blank,
      experience_years: value.experience_years ?? 0,
      education: value.education || blank,
      biography: value.biography || blank,
      qualifications: value.qualifications || blank,
      languages: value.languages || ["ru"],
      active: value.active ?? true,
      featured: value.featured ?? false,
      sort_order: value.sort_order || 0,
      specialty_ids: value.specialty_ids || [],
      service_ids: value.service_ids || [],
      photo_url: value.photo_url || null,
    };
  if (resource === "specialties")
    return {
      name: value.name || blank,
      description: value.description || blank,
      icon: value.icon || "medical",
      active: value.active ?? true,
      sort_order: value.sort_order || 0,
      doctor_ids: value.doctor_ids || [],
    };
  if (resource === "services")
    return {
      name: value.name || blank,
      description: value.description || blank,
      specialty_id: value.specialty_id || "",
      duration_minutes: value.duration_minutes || 30,
      price_rub: value.price_rub ?? 0,
      category_key: value.category_key || "consultations",
      category: value.category || blank,
      active: value.active ?? true,
      featured: value.featured ?? false,
      sort_order: value.sort_order || 0,
      doctor_ids: value.doctor_ids || [],
    };
  return {
    title: value.title || blank,
    description: value.description || blank,
    image_url: value.image_url || null,
    starts_at: value.starts_at || "",
    ends_at: value.ends_at || "",
    action_kind: value.action_kind || null,
    active: value.active ?? true,
    sort_order: value.sort_order || 0,
  };
}
const phone = z.string().regex(/^\+[0-9]{8,15}$/),
  clock = z.string().regex(/^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/);
export const settingsFormSchema = z.object({
  name,
  description: localized,
  address: name,
  phone: phone.nullable(),
  email: z.union([z.email(), z.literal(""), z.null()]),
  website: z.url().nullable(),
  timezone: z.string().min(1).max(100),
  logo_url: z.url().nullable(),
  image_url: z.url().nullable(),
  working_hours: z.record(z.string(), z.string().max(100)),
  booking: z.object({
    slot_step_minutes: z
      .number()
      .int()
      .min(5)
      .max(60)
      .refine((v) => v % 5 === 0 && 60 % v === 0),
  }),
  active: z.boolean(),
});
const weeklyShift = z
  .object({
    weekday: z.number().int().min(0).max(6),
    start: clock,
    end: z.union([clock, z.literal("24:00")]),
    breaks: z.array(z.object({ start: clock, end: clock })).max(8),
  })
  .superRefine((shift, ctx) => {
    if (shift.end <= shift.start)
      ctx.addIssue({ code: "custom", path: ["end"], message: "Invalid" });
    const breaks = [...shift.breaks].sort((a, b) =>
      a.start.localeCompare(b.start),
    );
    for (const [index, pause] of breaks.entries())
      if (
        pause.start < shift.start ||
        pause.end > shift.end ||
        pause.end <= pause.start ||
        (index && pause.start < breaks[index - 1].end)
      )
        ctx.addIssue({ code: "custom", path: ["breaks"], message: "Invalid" });
  });
export const scheduleFormSchema = z
  .object({
    weekly: z.array(weeklyShift).max(168),
    exceptions: z
      .array(
        z
          .object({
            starts_at: z.string().min(16),
            ends_at: z.string().min(16),
            available: z.boolean(),
          })
          .refine((v) => v.ends_at > v.starts_at, { path: ["ends_at"] }),
      )
      .max(400),
  })
  .superRefine((data, ctx) => {
    data.weekly.forEach((shift, index) => {
      if (
        data.weekly.some(
          (other, j) =>
            j !== index &&
            other.weekday === shift.weekday &&
            other.start < shift.end &&
            other.end > shift.start,
        )
      )
        ctx.addIssue({
          code: "custom",
          path: ["weekly", index, "start"],
          message: "Overlapping shift",
        });
    });
  });
export const staffFormSchema = z
  .object({
    user_id: z.union([z.uuid(), z.literal("")]),
    email: z.union([z.email(), z.literal("")]),
    role: z.enum(["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"]),
    doctor_id: z.union([z.uuid(), z.literal("")]),
    active: z.boolean(),
  })
  .refine((v) => Boolean(v.user_id || v.email), { path: ["email"] })
  .refine((v) => v.role !== "DOCTOR" || Boolean(v.doctor_id), {
    path: ["doctor_id"],
  });
export const systemFormSchema = z.object({
  booking_horizon_days: z.number().int().min(7).max(180),
  booking_enabled: z.boolean(),
});
