import { api, adminPath } from "./api";
const catalogs = new Set([
  "doctors",
  "specialties",
  "services",
  "promotions",
  "settings",
  "me",
]);
const selectors = new Set([
  "options",
  "filter-options",
  "catalog-options",
  "schedule-options",
]);
const lists = new Set([
  "appointments",
  "patients",
  "doctors",
  "specialties",
  "services",
  "promotions",
  "staff",
  "doctor-requests",
  "requests",
  "notifications",
]);
export function readPolicy(path) {
  const head = path.split("/")[0];
  return {
    staleTime:
      path === "availability"
        ? 0
        : selectors.has(path)
          ? 120000
          : catalogs.has(head)
            ? 60000
            : 15000,
    gcTime: 600000,
    refetchOnMount: path === "availability" ? "always" : true,
    refetchOnWindowFocus: true,
    retry: (count, error) =>
      ![400, 401, 403, 404, 409].includes(error.status) && count < 1,
  };
}
function previousPage(queryKey, path) {
  if (!lists.has(path)) return undefined;
  return (data, previous) => {
    const before = previous?.queryKey;
    if (!before || before[0] !== queryKey[0] || before[1] !== queryKey[1])
      return undefined;
    const paramsAt = queryKey[2] === "doctor" ? 4 : 3;
    if (
      before.length !== queryKey.length ||
      before.some((value, i) => i !== paramsAt && value !== queryKey[i])
    )
      return undefined;
    // Keep only another page of the same search/filter/sort; never cross tenants or roles.
    const { page: oldPage, ...oldFilters } = before[paramsAt] || {},
      { page: newPage, ...newFilters } = queryKey[paramsAt] || {};
    return JSON.stringify(oldFilters) === JSON.stringify(newFilters)
      ? data
      : undefined;
  };
}
export function adminQueryOptions(clinic, access, path, params = {}) {
  const key = [
    "clinic",
    clinic?.id,
    path,
    params,
    access?.role,
    access?.doctor_id,
  ];
  return {
    queryKey: key,
    queryFn: ({ signal }) => {
      if (access?.role === "DOCTOR") {
        const mapped =
          path === "filter-options"
            ? "options"
            : /^doctors\/[^/]+\/schedules$/.test(path)
              ? "schedule"
              : path;
        const { doctor_id, specialty_id, ...safe } = params;
        return api.get("/doctor/" + mapped, {
          params: { ...safe, clinic_id: clinic.id },
          signal,
        });
      }
      return api.get(adminPath(clinic.id, path), { params, signal });
    },
    ...readPolicy(path),
    placeholderData: previousPage(key, path),
  };
}
export function doctorQueryOptions(clinic, access, path, params = {}) {
  const key = ["clinic", clinic?.id, "doctor", path, params, access?.doctor_id];
  return {
    queryKey: key,
    queryFn: ({ signal }) =>
      api.get("/doctor/" + path, {
        params: { ...params, clinic_id: clinic.id },
        signal,
      }),
    ...readPolicy(path),
    placeholderData: previousPage(key, path),
  };
}
