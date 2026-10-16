// @vitest-environment jsdom
import { it, expect, vi } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useAdminQuery, useAdminMutation } from "./useAdmin";
const api = vi.hoisted(() => ({
  get: vi.fn(async () => ({ items: [] })),
  patch: vi.fn(async () => ({ status: "completed" })),
}));
vi.mock("../services/api", () => ({
  api,
  adminPath: (id, path) => `/admin/clinics/${id}/${path}`,
}));
vi.mock("../contexts/ClinicContext", () => ({
  useClinic: () => ({
    clinic: { id: "clinic-a" },
    access: { role: "DOCTOR", doctor_id: "verified-doctor" },
  }),
}));
vi.mock("../contexts/LocaleContext", () => ({
  useLocale: () => ({ t: (k) => k }),
}));
vi.mock("../contexts/ToastContext", () => ({ useToast: () => vi.fn() }));
function setup() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return {
    client,
    wrapper: ({ children }) => (
      <QueryClientProvider client={client}>{children}</QueryClientProvider>
    ),
  };
}
it("doctor calendar and own schedule use identity-derived endpoints rather than admin reads", async () => {
  const { client, wrapper } = setup();
  const calendar = renderHook(
    () =>
      useAdminQuery("calendar", {
        from: "start",
        to: "end",
        doctor_id: "forged-doctor",
      }),
    { wrapper },
  );
  await waitFor(() => expect(calendar.result.current.isSuccess).toBe(true));
  expect(api.get).toHaveBeenCalledWith(
    "/doctor/calendar",
    expect.objectContaining({
      params: { clinic_id: "clinic-a", from: "start", to: "end" },
    }),
  );
  const schedule = renderHook(
    () => useAdminQuery("doctors/forged-doctor/schedules"),
    { wrapper },
  );
  await waitFor(() => expect(schedule.result.current.isSuccess).toBe(true));
  expect(api.get).toHaveBeenCalledWith(
    "/doctor/schedule",
    expect.objectContaining({ params: { clinic_id: "clinic-a" } }),
  );
  calendar.unmount();
  schedule.unmount();
  client.clear();
});
it("doctor status action uses restricted doctor status endpoint and invalidates after success", async () => {
  const { client, wrapper } = setup(),
    invalidate = vi.spyOn(client, "invalidateQueries"),
    hook = renderHook(
      () => useAdminMutation("appointments/appointment-a", "patch"),
      { wrapper },
    );
  await act(async () => {
    await hook.result.current.mutateAsync({
      status: "completed",
      expected_updated_at: "version",
    });
  });
  expect(api.patch).toHaveBeenCalledWith(
    "/doctor/appointments/appointment-a/status",
    {
      clinic_id: "clinic-a",
      status: "completed",
      expected_updated_at: "version",
    },
  );
  expect(invalidate).toHaveBeenCalledWith({ queryKey: ["clinic", "clinic-a"] });
  hook.unmount();
  client.clear();
});
it("doctor arrival queue mutations use the own-doctor attendance endpoint with a row version", async () => {
  const { client, wrapper } = setup();
  const hook = renderHook(
    () => useAdminMutation("appointments/appointment-a/attendance", "patch"),
    { wrapper },
  );
  await act(async () => {
    await hook.result.current.mutateAsync({
      status: "in_consultation",
      expected_updated_at: "version",
    });
  });
  expect(api.patch).toHaveBeenCalledWith(
    "/doctor/appointments/appointment-a/attendance",
    {
      clinic_id: "clinic-a",
      status: "in_consultation",
      expected_updated_at: "version",
    },
  );
  hook.unmount();
  client.clear();
});
