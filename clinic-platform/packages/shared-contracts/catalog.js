import { z } from "zod";
import { clinicIdSchema, localizedTextSchema } from "./index.js";
export const catalogQuerySchema = z
  .object({
    search: z.string().trim().max(100).default(""),
    specialtyId: clinicIdSchema.optional(),
    serviceId: clinicIdSchema.optional(),
    doctorId: clinicIdSchema.optional(),
    category: z
      .string()
      .regex(/^[a-z_]{1,40}$/)
      .optional(),
    page: z.coerce.number().int().min(1).max(1000).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(12),
    sort: z
      .enum(["name", "price_asc", "price_desc", "experience_desc", "featured"])
      .default("featured"),
    locale: z.enum(["ru", "en"]).default("ru"),
  })
  .strict();
export const paginationSchema = z.object({
  page: z.number().int(),
  limit: z.number().int(),
  total: z.number().int().nonnegative(),
  hasMore: z.boolean(),
});
export const specialtyReferenceSchema = z.object({
  id: clinicIdSchema,
  name: localizedTextSchema,
});
export const specialtyCatalogSchema = z.object({
  id: clinicIdSchema,
  clinic_id: clinicIdSchema,
  name: localizedTextSchema,
  description: localizedTextSchema,
  icon: z.string(),
  doctor_count: z.number().int().nonnegative(),
  sort_order: z.number().int(),
});
export const doctorCatalogSchema = z.object({
  id: clinicIdSchema,
  clinic_id: clinicIdSchema,
  name: localizedTextSchema,
  description: localizedTextSchema,
  photo_url: z.url().nullable(),
  professional_title: localizedTextSchema,
  experience_years: z.number().int().nullable(),
  specialties: z.array(specialtyReferenceSchema),
  starting_price_rub: z.number().nonnegative().nullable(),
});
export const serviceCatalogSchema = z.object({
  id: clinicIdSchema,
  clinic_id: clinicIdSchema,
  specialty_id: clinicIdSchema,
  specialty_name: localizedTextSchema,
  name: localizedTextSchema,
  description: localizedTextSchema,
  price_rub: z.number().nonnegative(),
  duration_minutes: z.number().int().positive(),
  category_key: z.string(),
  category: localizedTextSchema,
});
export const promotionSchema = z.object({
  id: clinicIdSchema,
  clinic_id: clinicIdSchema,
  title: localizedTextSchema,
  description: localizedTextSchema,
  image_url: z.url().nullable(),
  action_kind: z.enum(["doctors", "specialties", "services"]).nullable(),
  starts_at: z.string(),
  ends_at: z.string(),
});
