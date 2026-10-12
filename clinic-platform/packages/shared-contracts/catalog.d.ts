import { z } from "zod";
export interface CatalogQuery {
  search: string;
  specialtyId?: string;
  serviceId?: string;
  doctorId?: string;
  category?: string;
  page: number;
  limit: number;
  sort: "name" | "price_asc" | "price_desc" | "experience_desc" | "featured";
  locale: "ru" | "en";
}
export declare const catalogQuerySchema: z.ZodType<CatalogQuery>;
export declare const paginationSchema: z.ZodType<{
  page: number;
  limit: number;
  total: number;
  hasMore: boolean;
}>;
export declare const specialtyReferenceSchema: z.ZodType<{
  id: string;
  name: { ru: string; en: string };
}>;
export declare const specialtyCatalogSchema: z.ZodType<Record<string, unknown>>;
export declare const doctorCatalogSchema: z.ZodType<Record<string, unknown>>;
export declare const serviceCatalogSchema: z.ZodType<Record<string, unknown>>;
export declare const promotionSchema: z.ZodType<Record<string, unknown>>;
