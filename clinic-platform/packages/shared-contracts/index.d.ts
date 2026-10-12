import { z } from 'zod';
export declare const clinicIdSchema: z.ZodUUID;
export declare const localizedTextSchema: z.ZodObject<{ru: z.ZodString; en: z.ZodString}>;
export declare const clinicSchema: z.ZodObject<{id: z.ZodUUID; slug: z.ZodString; name: typeof localizedTextSchema; address: typeof localizedTextSchema; timezone: z.ZodString; description: typeof localizedTextSchema; image_url: z.ZodNullable<z.ZodURL>}>;
export declare const clinicListSchema: z.ZodArray<typeof clinicSchema>;
export declare const appointmentStatusSchema: z.ZodEnum<{pending:'pending'; confirmed:'confirmed'; completed:'completed'; cancelled:'cancelled'; no_show:'no_show'}>;
export type Clinic = z.infer<typeof clinicSchema>;
export type ApiResponse<T> = {success:true; data:T; message:string} | {success:false; error:{code:string;message:string;details:Record<string,unknown>}};
