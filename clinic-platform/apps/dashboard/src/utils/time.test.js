import { it, expect } from "vitest";
import { rangeFor, toInstant, dateInput } from "./time";
import { allowed, clinicAccess } from "./permissions";
import { catalogSchemas } from "./formSchemas";
import { translations } from "./translations";
it("uses local clinic midnight across DST without assuming a 24-hour day", () => {
  const spring = rangeFor("2026-03-29", "day", "Europe/Berlin");
  expect((Date.parse(spring.to) - Date.parse(spring.from)) / 3600000).toBe(23);
  expect(toInstant("2026-10-12T09:00", "Europe/Moscow")).toBe(
    "2026-10-12T06:00:00.000Z",
  );
  expect(dateInput("2026-10-12T06:00:00Z", "Europe/Moscow")).toBe(
    "2026-10-12T09:00",
  );
});
it("shows role-scoped navigation while selecting the strongest actual clinic membership", () => {
  expect(allowed("RECEPTIONIST", "staff")).toBe(false);
  expect(allowed("DOCTOR", "patients")).toBe(false);
  expect(allowed("DOCTOR", "schedules")).toBe(true);
  expect(
    clinicAccess(
      [
        { role: "CLINIC_ADMIN", clinic_id: "a" },
        { role: "RECEPTIONIST", clinic_id: "b" },
      ],
      "b",
    ).role,
  ).toBe("RECEPTIONIST");
});
it("rejects incomplete localized content and invalid prices", () => {
  expect(
    catalogSchemas.services.safeParse({
      name: { ru: "", en: "" },
      price_rub: -1,
    }).success,
  ).toBe(false);
  expect(
    catalogSchemas.promotions.safeParse({
      starts_at: "2026-10-13",
      ends_at: "2026-10-12",
    }).success,
  ).toBe(false);
});
it("has matching Russian and English translation coverage", () => {
  expect(Object.keys(translations.ru).sort()).toEqual(
    Object.keys(translations.en).sort(),
  );
});

it("rejects missing and ambiguous DST wall times instead of shifting bookings silently", () => {
  expect(toInstant("2026-03-29T02:30", "Europe/Berlin")).toBeNull();
  expect(toInstant("2026-10-25T02:30", "Europe/Berlin")).toBeNull();
});
