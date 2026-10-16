import {
  AppError,
  ResourceNotFoundError,
} from "../../common/errors/app-error.js";
import type { ClinicRepository } from "../clinics/repository.js";
import type { CatalogRepository, Kind, Query, Page, Row } from "./types.js";
export class CatalogService {
  constructor(
    private catalog: CatalogRepository,
    private clinics: ClinicRepository,
  ) {}
  private scoped(row: Row, clinic: string): Row {
    if (row.clinic_id !== clinic)
      throw new AppError(
        500,
        "INVALID_CATALOG_DATA",
        "Catalog information could not be loaded",
      );
    return row;
  }
  private scopedPage(page: Page, clinic: string): Page {
    return {
      ...page,
      items: page.items.map((row) => this.scoped(row, clinic)),
    };
  }
  async list(kind: Kind, clinic: string, q: Query) {
    await this.clinics.get(clinic);
    return this.scopedPage(await this.catalog.list(kind, clinic, q), clinic);
  }
  async detail(
    kind: Exclude<Kind, "promotions">,
    clinic: string,
    id: string,
    q: Query,
  ) {
    const clinicInfo = await this.clinics.get(clinic);
    const row = await this.catalog.detail(kind, clinic, id);
    if (!row) throw new ResourceNotFoundError();
    this.scoped(row, clinic);
    if (kind === "doctors") {
      const [services, schedules] = await Promise.all([
        this.catalog.list("services", clinic, { ...q, doctorId: id }),
        this.catalog.schedules(clinic, id),
      ]);
      return {
        ...row,
        clinic: clinicInfo,
        services: this.scopedPage(services, clinic),
        schedules,
      };
    }
    if (kind === "specialties") {
      const [doctors, services] = await Promise.all([
        this.catalog.list("doctors", clinic, { ...q, specialtyId: id }),
        this.catalog.list("services", clinic, { ...q, specialtyId: id }),
      ]);
      return {
        ...row,
        doctors: this.scopedPage(doctors, clinic),
        services: this.scopedPage(services, clinic),
      };
    }
    const doctors = await this.catalog.list("doctors", clinic, {
      ...q,
      serviceId: id,
    });
    return {
      ...row,
      clinic: clinicInfo,
      doctors: this.scopedPage(doctors, clinic),
    };
  }
  async bookingContext(clinic: string, q: Query) {
    const info = await this.clinics.get(clinic);
    const read = async (
      kind: "doctors" | "services" | "specialties",
      id?: string,
    ) => {
      if (!id) return null;
      const row = await this.catalog.detail(kind, clinic, id);
      if (!row) throw new ResourceNotFoundError();
      return this.scoped(row, clinic);
    };
    const [doctor, service, specialty] = await Promise.all([
      read("doctors", q.doctorId),
      read("services", q.serviceId),
      read("specialties", q.specialtyId),
    ]);
    if (
      q.doctorId &&
      q.serviceId &&
      !(await this.catalog.offers(clinic, q.doctorId, q.serviceId))
    )
      throw new AppError(
        400,
        "INVALID_BOOKING_SELECTION",
        "The selected doctor does not offer this service in this clinic",
      );
    if (service && q.specialtyId && service.specialty_id !== q.specialtyId)
      throw new AppError(
        400,
        "INVALID_BOOKING_SELECTION",
        "Service and specialty do not match",
      );
    if (
      doctor &&
      q.specialtyId &&
      !(doctor.specialties as { id: string }[]).some(
        (s) => s.id === q.specialtyId,
      )
    )
      throw new AppError(
        400,
        "INVALID_BOOKING_SELECTION",
        "Doctor and specialty do not match",
      );
    return {
      clinic: info,
      doctor,
      service,
      specialty,
      online_booking_enabled: true,
    };
  }
  async home(clinic: string, q: Query) {
    const info = await this.clinics.get(clinic);
    const [promotions, specialties, doctors, services] = await Promise.all([
      this.catalog.list("promotions", clinic, { ...q, page: 1, limit: 4 }),
      this.catalog.list("specialties", clinic, { ...q, page: 1, limit: 6 }),
      this.catalog.list("doctors", clinic, {
        ...q,
        page: 1,
        limit: 3,
        featured: true,
      }),
      this.catalog.list("services", clinic, {
        ...q,
        page: 1,
        limit: 4,
        featured: true,
      }),
    ]);
    return {
      clinic: info,
      promotions: this.scopedPage(promotions, clinic).items,
      specialties: this.scopedPage(specialties, clinic).items,
      doctors: this.scopedPage(doctors, clinic).items,
      services: this.scopedPage(services, clinic).items,
    };
  }
}
