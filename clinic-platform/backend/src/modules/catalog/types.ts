import type { CatalogQuery } from "@clinic/shared-contracts/catalog";
export type Kind = "doctors" | "specialties" | "services" | "promotions";
export type Row = Record<string, unknown>;
export interface Page {
  items: Row[];
  pagination: { page: number; limit: number; total: number; hasMore: boolean };
  categories?: Row[];
}
export type Query = CatalogQuery & { featured?: boolean; doctorId?: string };
export interface CatalogRepository {
  list(kind: Kind, clinicId: string, query: Query): Promise<Page>;
  detail(
    kind: Exclude<Kind, "promotions">,
    clinicId: string,
    id: string,
  ): Promise<Row | null>;
  schedules(clinicId: string, doctorId: string): Promise<Row[]>;
  offers(
    clinicId: string,
    doctorId: string,
    serviceId: string,
  ): Promise<boolean>;
}
