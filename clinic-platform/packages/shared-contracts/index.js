import { z } from 'zod';
export const clinicIdSchema = z.uuid();
export const localizedTextSchema = z.object({ ru: z.string(), en: z.string() });
export const clinicSchema = z.object({ id: clinicIdSchema, slug: z.string(), name: localizedTextSchema, address: localizedTextSchema, timezone: z.string(), description: localizedTextSchema, image_url: z.url().nullable() });
export const clinicListSchema = z.array(clinicSchema);
export const appointmentStatusSchema = z.enum(['pending', 'confirmed', 'completed', 'cancelled', 'no_show']);
