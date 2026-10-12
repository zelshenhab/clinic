export function clinicAccess(memberships, clinicId) {
  return (
    memberships?.find((m) => m.role === "SUPER_ADMIN") ||
    memberships?.find(
      (m) => m.clinic_id === clinicId && m.role === "CLINIC_ADMIN",
    ) ||
    memberships?.find(
      (m) => m.clinic_id === clinicId && m.role === "RECEPTIONIST",
    ) ||
    memberships?.find((m) => m.clinic_id === clinicId)
  );
}
export const allowed = (role, operation) =>
  role === "SUPER_ADMIN" ||
  (
    {
      overview: ["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"],
      appointments: ["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"],
      calendar: ["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"],
      book: ["CLINIC_ADMIN", "RECEPTIONIST"],
      catalog: ["CLINIC_ADMIN"],
      patients: ["CLINIC_ADMIN", "RECEPTIONIST"],
      schedules: ["CLINIC_ADMIN", "DOCTOR"],
      scheduleWrite: ["CLINIC_ADMIN"],
      settings: ["CLINIC_ADMIN"],
      staff: [],
    }[operation] || []
  ).includes(role);
