import { it, expect } from "vitest";
import { authorize } from "../src/modules/admin/permissions.js";
const row = (
  role: any,
  clinic_id: string | null = "a",
  doctor_id: string | null = null,
) => ({ id: "membership", role, clinic_id, doctor_id });
it("allows a server-verified super administrator across clinics", () => {
  expect(authorize([row("SUPER_ADMIN", null)], "u", "b", "staff").role).toBe(
    "SUPER_ADMIN",
  );
});
it("denies clinic admin outside assigned clinic", () => {
  expect(() => authorize([row("CLINIC_ADMIN")], "u", "b", "catalog")).toThrow();
  expect(authorize([row("CLINIC_ADMIN")], "u", "a", "catalog").role).toBe(
    "CLINIC_ADMIN",
  );
});
it("receptionists can book but cannot edit catalog/settings/staff", () => {
  expect(authorize([row("RECEPTIONIST")], "u", "a", "book").role).toBe(
    "RECEPTIONIST",
  );
  for (const op of ["catalog", "settings", "staff"])
    expect(() => authorize([row("RECEPTIONIST")], "u", "a", op)).toThrow();
});
it("doctor access carries its verified doctor identity and cannot book/edit schedules", () => {
  const rows = [row("DOCTOR", "a", "doctor")];
  expect(authorize(rows, "u", "a", "appointments").doctorId).toBe("doctor");
  for (const op of ["book", "patients", "catalog", "scheduleWrite", "records"])
    expect(() => authorize(rows, "u", "a", op)).toThrow();
  expect(() => authorize([row("DOCTOR")], "u", "a", "appointments")).toThrow();
});
it("clinic admins and receptionists manage medical documents through the admin routes", () => {
  for (const role of ["CLINIC_ADMIN", "RECEPTIONIST"])
    expect(authorize([row(role)], "u", "a", "records").role).toBe(role);
});
