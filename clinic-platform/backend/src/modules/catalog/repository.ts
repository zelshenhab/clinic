import type { SupabaseClient } from "@supabase/supabase-js";
import { AppError } from "../../common/errors/app-error.js";
import type { CatalogRepository, Kind, Page, Query, Row } from "./types.js";
const fields = {
  doctors:
    "id,clinic_id,name,description,photo_url,professional_title,experience_years,specialties,starting_price_rub",
  specialties: "id,clinic_id,name,description,icon,doctor_count,sort_order",
  services:
    "id,clinic_id,specialty_id,specialty_name,name,description,price_rub,duration_minutes,category_key,category",
  promotions:
    "id,clinic_id,title,description,image_url,action_kind,starts_at,ends_at",
};
function unavailable() {
  return new AppError(
    503,
    "DATABASE_UNAVAILABLE",
    "Medical catalog is temporarily unavailable",
  );
}
export function catalogRepository(
  db: SupabaseClient,
  now = () => new Date(),
): CatalogRepository {
  async function list(kind: Kind, clinicId: string, q: Query): Promise<Page> {
    const table = kind === "promotions" ? "promotions" : `catalog_${kind}`;
    let query = db
      .from(table)
      .select(fields[kind], { count: "exact" })
      .eq("clinic_id", clinicId);
    if (kind === "promotions")
      query = query
        .eq("active", true)
        .lte("starts_at", now().toISOString())
        .gt("ends_at", now().toISOString());
    if (q.search && kind !== "promotions")
      query = query.ilike(
        "search_text",
        `%${q.search.replace(/[\\%_]/g, (c) => "\\" + c)}%`,
      );
    if (q.specialtyId && kind === "doctors")
      query = query.contains("specialty_ids", [q.specialtyId]);
    if (q.specialtyId && kind === "services")
      query = query.eq("specialty_id", q.specialtyId);
    if (q.serviceId && kind === "doctors")
      query = query.contains("service_ids", [q.serviceId]);
    if (q.category && kind === "services")
      query = query.eq("category_key", q.category);
    if (q.doctorId && kind === "services")
      query = query.contains("doctor_ids", [q.doctorId]);
    if (q.featured !== undefined && (kind === "doctors" || kind === "services"))
      query = query.eq("featured", q.featured);
    if (q.sort === "name" && kind !== "promotions")
      query = query.order(q.locale === "ru" ? "name_ru" : "name_en");
    else if (
      (q.sort === "price_asc" || q.sort === "price_desc") &&
      (kind === "services" || kind === "doctors")
    )
      query = query.order(
        kind === "doctors" ? "starting_price_rub" : "price_rub",
        { ascending: q.sort === "price_asc", nullsFirst: false },
      );
    else if (q.sort === "experience_desc" && kind === "doctors")
      query = query.order("experience_years", {
        ascending: false,
        nullsFirst: false,
      });
    else query = query.order("sort_order");
    query = query
      .order("id")
      .range((q.page - 1) * q.limit, q.page * q.limit - 1);
    const { data, error, count } = await query;
    if (error || count === null) throw unavailable();
    const result: Page = {
      items: (data ?? []) as unknown as Row[],
      pagination: {
        page: q.page,
        limit: q.limit,
        total: count,
        hasMore: q.page * q.limit < count,
      },
    };
    if (kind === "services") {
      const { data: categories, error: categoryError } = await db
        .from("catalog_categories")
        .select("category_key,category")
        .eq("clinic_id", clinicId)
        .order("category_key");
      if (categoryError) throw unavailable();
      result.categories = categories ?? [];
    }
    return result;
  }
  return {
    list,
    offers: async (clinicId, doctorId, serviceId) => {
      const { data, error } = await db
        .from("catalog_doctors")
        .select("id")
        .eq("clinic_id", clinicId)
        .eq("id", doctorId)
        .contains("service_ids", [serviceId])
        .maybeSingle();
      if (error) throw unavailable();
      return data !== null;
    },
    detail: async (kind, clinicId, id) => {
      const extra =
        kind === "doctors"
          ? ",education,biography,qualifications,languages"
          : "";
      const { data, error } = await db
        .from(`catalog_${kind}`)
        .select(fields[kind] + extra)
        .eq("clinic_id", clinicId)
        .eq("id", id)
        .maybeSingle();
      if (error) throw unavailable();
      return data as unknown as Row | null;
    },
    schedules: async (clinicId, doctorId) => {
      const { data, error } = await db
        .from("doctor_schedules")
        .select("weekday,starts_at,ends_at,breaks")
        .eq("clinic_id", clinicId)
        .eq("doctor_id", doctorId)
        .order("weekday")
        .order("starts_at");
      if (error) throw unavailable();
      return data ?? [];
    },
  };
}
