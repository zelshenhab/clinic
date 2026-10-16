import { it, expect, vi, beforeEach } from "vitest";
import { QueryClient } from "@tanstack/react-query";
import { adminQueryOptions, doctorQueryOptions, readPolicy } from "./queries";
import { navigationReads } from "../hooks/useNavigationPrefetch";
const api = vi.hoisted(() => ({
  get: vi.fn(async () => ({ items: [], pagination: { page: 1 } })),
}));
vi.mock("./api", () => ({
  api,
  adminPath: (id, path) => `/admin/clinics/${id}/${path}`,
}));
const clinic = { id: "clinic-a", timezone: "Europe/Moscow" },
  admin = { role: "SUPER_ADMIN" },
  doctor = { role: "DOCTOR", doctor_id: "doctor-a" };
beforeEach(() => vi.clearAllMocks());
it("prefetched catalog data is reused by the actual page without another request", async () => {
  const client = new QueryClient(),
    prefetch = navigationReads("doctors", clinic, admin)[0],
    page = adminQueryOptions(clinic, admin, "doctors", {
      search: "",
      page: 1,
      limit: 20,
    });
  expect(prefetch.queryKey).toEqual(page.queryKey);
  await client.prefetchQuery(prefetch);
  await client.fetchQuery(page);
  expect(api.get).toHaveBeenCalledTimes(1);
  await client.invalidateQueries({ queryKey: ["clinic", clinic.id] });
  await client.fetchQuery(page);
  expect(api.get).toHaveBeenCalledTimes(2);
  client.clear();
});
it("availability is never treated as fresh cached data", async () => {
  const client = new QueryClient(),
    options = adminQueryOptions(clinic, admin, "availability", {
      doctor_id: "doctor-a",
    });
  expect(options.staleTime).toBe(0);
  expect(options.refetchOnMount).toBe("always");
  await client.fetchQuery(options);
  await client.fetchQuery(options);
  expect(api.get).toHaveBeenCalledTimes(2);
  expect(options.placeholderData).toBeUndefined();
  client.clear();
});
it("previous page rows cannot cross clinic, role, doctor, search or resource boundaries", () => {
  const q = adminQueryOptions(clinic, admin, "patients", {
      search: "",
      page: 2,
      limit: 20,
    }),
    data = { items: [{ id: "private-patient" }] },
    previous = adminQueryOptions(clinic, admin, "patients", {
      search: "",
      page: 1,
      limit: 20,
    });
  expect(q.placeholderData(data, previous)).toBe(data);
  expect(
    q.placeholderData(
      data,
      adminQueryOptions({ id: "clinic-b" }, admin, "patients", {
        search: "",
        page: 1,
        limit: 20,
      }),
    ),
  ).toBeUndefined();
  expect(
    q.placeholderData(
      data,
      adminQueryOptions(clinic, { role: "RECEPTIONIST" }, "patients", {
        search: "",
        page: 1,
        limit: 20,
      }),
    ),
  ).toBeUndefined();
  expect(
    q.placeholderData(
      data,
      adminQueryOptions(clinic, admin, "patients", {
        search: "other",
        page: 1,
        limit: 20,
      }),
    ),
  ).toBeUndefined();
  const own = doctorQueryOptions(clinic, doctor, "patients", { page: 2 });
  expect(
    own.placeholderData(
      data,
      doctorQueryOptions(
        clinic,
        { ...doctor, doctor_id: "doctor-b" },
        "patients",
        { page: 1 },
      ),
    ),
  ).toBeUndefined();
});
it("doctor prefetch uses identical scoped cache keys and only intended doctor reads", () => {
  expect(navigationReads("patients", clinic, doctor)[0].queryKey).toEqual(
    doctorQueryOptions(clinic, doctor, "patients", {
      search: "",
      page: 1,
      limit: 20,
    }).queryKey,
  );
  expect(navigationReads("settings", clinic, doctor)).toEqual([]);
  expect(
    navigationReads("schedules", clinic, doctor).map((q) => q.queryKey[3]),
  ).toEqual(["schedule", "requests"]);
  expect(readPolicy("services").staleTime).toBeGreaterThan(
    readPolicy("appointments").staleTime,
  );
});
