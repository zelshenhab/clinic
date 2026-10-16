import { z } from "zod";
const uuid = z.uuid(),
  localized = z
    .object({
      ru: z.string().trim().max(5000),
      en: z.string().trim().max(5000),
    })
    .strict();
const name = z
  .object({
    ru: z.string().trim().min(2).max(200),
    en: z.string().trim().min(2).max(200),
  })
  .strict();
const optionalUrl = z
  .url()
  .max(2000)
  .refine((value) => {
    const url = new URL(value);
    return (
      url.protocol === "https:" ||
      (process.env.NODE_ENV !== "production" &&
        url.protocol === "http:" &&
        ["localhost", "127.0.0.1"].includes(url.hostname))
    );
  })
  .nullable();
const ids = z
  .array(uuid)
  .max(100)
  .refine((v) => new Set(v).size === v.length);
export const resourceSchemas = {
  doctors: z
    .object({
      doctor_id: uuid.optional(),
      name,
      description: localized,
      professional_title: localized,
      experience_years: z.number().int().min(0).max(80).nullable(),
      education: localized,
      biography: localized,
      qualifications: localized,
      languages: z.array(z.enum(["ru", "en"])).max(2),
      photo_url: optionalUrl.optional(),
      active: z.boolean(),
      featured: z.boolean(),
      sort_order: z.number().int().min(0).max(10000),
      specialty_ids: ids,
      service_ids: ids,
    })
    .strict(),
  specialties: z
    .object({
      name,
      description: localized,
      icon: z.enum([
        "medical",
        "heart",
        "brain",
        "skin",
        "eye",
        "scan",
        "child",
        "tooth",
        "bone",
      ]),
      active: z.boolean(),
      sort_order: z.number().int().min(0).max(10000),
      doctor_ids: ids.optional(),
    })
    .strict(),
  services: z
    .object({
      name,
      description: localized,
      specialty_id: uuid,
      duration_minutes: z.number().int().min(5).max(480),
      price_rub: z.number().min(0).max(1000000).multipleOf(0.01),
      category_key: z.string().regex(/^[a-z_]{1,40}$/),
      category: name,
      active: z.boolean(),
      featured: z.boolean(),
      sort_order: z.number().int().min(0).max(10000),
      doctor_ids: ids.optional(),
    })
    .strict(),
  promotions: z
    .object({
      title: name,
      description: localized,
      image_url: optionalUrl.optional(),
      starts_at: z.iso.datetime({ offset: true }),
      ends_at: z.iso.datetime({ offset: true }),
      action_kind: z.enum(["doctors", "services", "specialties"]).nullable(),
      active: z.boolean(),
      sort_order: z.number().int().min(0).max(10000),
    })
    .strict(),
};
export type Resource = keyof typeof resourceSchemas;
export const listSchema = z
  .object({
    search: z.string().trim().max(100).optional(),
    page: z.coerce.number().int().min(1).max(1000).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    sort: z.enum(["newest", "oldest"]).default("newest"),
    patient_id: uuid.optional(),
    doctor_id: uuid.optional(),
    specialty_id: uuid.optional(),
    service_id: uuid.optional(),
    status: z
      .enum(["pending", "confirmed", "completed", "cancelled", "no_show"])
      .optional(),
    active: z.enum(["true", "false"]).optional(),
    from: z.iso.datetime({ offset: true }).optional(),
    to: z.iso.datetime({ offset: true }).optional(),
  })
  .strict()
  .refine((q) => !q.from || !q.to || new Date(q.to) > new Date(q.from));
export const bookSchema = z
  .object({
    patient_id: uuid,
    doctor_id: uuid,
    service_id: uuid,
    starts_at: z.iso.datetime({ offset: true }),
  })
  .strict();
export const changeSchema = z
  .object({
    expected_updated_at: z.iso.datetime({ offset: true }),
    status: z
      .enum(["confirmed", "completed", "cancelled", "no_show"])
      .optional(),
    starts_at: z.iso.datetime({ offset: true }).optional(),
  })
  .strict()
  .refine((v) => Boolean(v.status) !== Boolean(v.starts_at));
export const availabilitySchema = z
  .object({ doctor_id: uuid, service_id: uuid, date: z.iso.date() })
  .strict();
export const dashboardSchema = z
  .object({ from: z.iso.date(), to: z.iso.date() })
  .strict()
  .refine(
    (v) =>
      v.to >= v.from && Date.parse(v.to) - Date.parse(v.from) <= 366 * 86400000,
  );
const time = z.string().regex(/^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/),
  minute = (value: string) =>
    Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
const shift = z
  .object({
    weekday: z.number().int().min(0).max(6),
    starts_at: time,
    ends_at: z.union([time, z.literal("24:00")]),
    breaks: z.array(z.object({ start: time, end: time }).strict()).max(8),
  })
  .strict()
  .superRefine((s, ctx) => {
    const breaks = [...s.breaks].sort((a, b) => a.start.localeCompare(b.start));
    if (
      s.ends_at <= s.starts_at ||
      breaks.some(
        (b, i) =>
          b.start < s.starts_at ||
          b.end > s.ends_at ||
          b.end <= b.start ||
          (i > 0 && b.start < breaks[i - 1]!.end),
      )
    )
      ctx.addIssue({
        code: "custom",
        message: "Invalid working hours or breaks",
      });
  });
export const scheduleSchema = z
  .object({
    weekly: z.array(shift).max(168),
    exceptions: z
      .array(
        z
          .object({
            starts_at: z.iso.datetime({ offset: true }),
            ends_at: z.iso.datetime({ offset: true }),
            available: z.boolean(),
          })
          .strict()
          .refine((v) => Date.parse(v.ends_at) > Date.parse(v.starts_at)),
      )
      .max(100),
  })
  .strict()
  .superRefine((v, ctx) => {
    const shifts = [...v.weekly].sort(
      (a, b) =>
        a.weekday - b.weekday || minute(a.starts_at) - minute(b.starts_at),
    );
    if (
      shifts.some(
        (s, i) =>
          i > 0 &&
          s.weekday === shifts[i - 1]!.weekday &&
          s.starts_at < shifts[i - 1]!.ends_at,
      )
    )
      ctx.addIssue({ code: "custom", message: "Overlapping shifts" });
  });
export const settingsSchema = z
  .object({
    name: name.optional(),
    description: localized.optional(),
    address: name.optional(),
    phone: z
      .string()
      .regex(/^\+[0-9]{8,15}$/)
      .nullable()
      .optional(),
    email: z.email().nullable().optional(),
    website: optionalUrl.optional(),
    timezone: z.string().max(100).optional(),
    logo_url: optionalUrl.optional(),
    image_url: optionalUrl.optional(),
    working_hours: z.record(z.string().max(30), z.string().max(100)).optional(),
    active: z.boolean().optional(),
    booking: z
      .object({
        slot_step_minutes: z
          .number()
          .int()
          .min(5)
          .max(60)
          .refine((v) => 60 % v === 0 && v % 5 === 0),
      })
      .strict()
      .optional(),
  })
  .strict()
  .refine((v) => Object.keys(v).length > 0);
export const patientSchema = z
  .object({
    user_id: uuid.optional(),
    email: z.email().max(200).optional(),
    full_name: z.string().trim().min(2).max(120),
    phone: z.string().regex(/^\+[0-9]{8,15}$/),
    language: z.enum(["ru", "en"]),
  })
  .strict()
  .refine((v) => Boolean(v.user_id || v.email));
export const staffSchema = z
  .object({
    user_id: uuid.optional(),
    email: z.email().max(200).optional(),
    role: z.enum(["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"]),
    doctor_id: uuid.nullable().optional(),
    active: z.boolean(),
  })
  .strict()
  .refine((v) => Boolean(v.user_id) || Boolean(v.email))
  .refine((v) => v.role !== "DOCTOR" || Boolean(v.doctor_id));
export { uuid };

export const calendarSchema = z
  .object({
    from: z.iso.datetime({ offset: true }),
    to: z.iso.datetime({ offset: true }),
    doctor_id: uuid.optional(),
  })
  .strict()
  .refine(
    (v) =>
      Date.parse(v.to) > Date.parse(v.from) &&
      Date.parse(v.to) - Date.parse(v.from) <= 43 * 86400000,
  );
