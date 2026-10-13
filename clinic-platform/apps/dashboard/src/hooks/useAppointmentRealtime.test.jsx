// @vitest-environment jsdom
import { it, expect, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useAppointmentRealtime } from "./useAppointmentRealtime";
const state = vi.hoisted(() => ({
  clinic: "clinic-a",
  role: "CLINIC_ADMIN",
  doctor: null,
  handlers: {},
  payload: null,
  status: null,
  remove: vi.fn(),
  channels: [],
}));
vi.mock("../contexts/AuthContext", () => ({
  useAuth: () => ({
    session: { access_token: "verified-token", user: { id: "staff" } },
  }),
}));
vi.mock("../contexts/ClinicContext", () => ({
  useClinic: () => ({
    clinic: { id: state.clinic },
    access: { role: state.role, doctor_id: state.doctor },
  }),
}));
vi.mock("../services/supabase", () => ({
  supabase: {
    realtime: { setAuth: vi.fn(async () => {}) },
    channel: vi.fn((name, config) => {
      state.channels.push({ name, config });
      const channel = {
        on: (_type, _event, callback) => {
          state.handlers[_event.event] = callback;
          state.payload = callback;
          return channel;
        },
        subscribe: (callback) => {
          state.status = callback;
          return channel;
        },
      };
      return channel;
    }),
    removeChannel: state.remove,
  },
}));
it("deduplicates minimal events, invalidates only its clinic, refetches on reconnect and cleans up", async () => {
  const client = new QueryClient(),
    invalidate = vi.spyOn(client, "invalidateQueries");
  const wrapper = ({ children }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );
  const hook = renderHook(() => useAppointmentRealtime(), { wrapper });
  await waitFor(() => expect(state.status).toBeTypeOf("function"));
  act(() => state.status("SUBSCRIBED"));
  expect(invalidate).toHaveBeenCalledWith({ queryKey: ["clinic", "clinic-a"] });
  const event = { payload: { clinic_id: "clinic-a", event_id: "uuid-event" } };
  act(() => {
    state.payload(event);
    state.payload(event);
    state.payload({
      payload: { clinic_id: "clinic-b", event_id: "wrong-clinic" },
    });
  });
  await waitFor(() => expect(hook.result.current.events).toHaveLength(1));
  await new Promise((resolve) => setTimeout(resolve, 175));
  expect(invalidate).toHaveBeenCalledTimes(2);
  act(() => state.status("SUBSCRIBED"));
  expect(invalidate).toHaveBeenCalledTimes(3);
  state.clinic = "clinic-b";
  hook.rerender();
  await waitFor(() => expect(state.channels).toHaveLength(2));
  expect(state.remove).toHaveBeenCalledTimes(1);
  expect(hook.result.current.events).toEqual([]);
  expect(state.channels[1]).toEqual({
    name: "staff:clinic-b:staff",
    config: { config: { private: true } },
  });
  hook.unmount();
  expect(state.remove).toHaveBeenCalledTimes(2);
  client.clear();
});

it("doctor appointment and request events use the private user topic and reset on identity change", async () => {
  state.clinic = "clinic-a";
  state.role = "DOCTOR";
  state.doctor = "doctor-a";
  const client = new QueryClient(),
    invalidate = vi.spyOn(client, "invalidateQueries"),
    wrapper = ({ children }) => (
      <QueryClientProvider client={client}>{children}</QueryClientProvider>
    );
  const hook = renderHook(() => useAppointmentRealtime(), { wrapper });
  await waitFor(() =>
    expect(state.handlers.appointment_changed).toBeTypeOf("function"),
  );
  expect(state.channels.at(-1)).toEqual({
    name: "staff:clinic-a:staff",
    config: { config: { private: true } },
  });
  act(() =>
    state.handlers.appointment_changed({
      payload: { clinic_id: "clinic-a", event_id: "new-appointment" },
    }),
  );
  act(() =>
    state.handlers.doctor_request_changed({
      payload: {
        clinic_id: "clinic-a",
        event_id: "review-result",
        request_id: "request-a",
      },
    }),
  );
  await waitFor(() => expect(hook.result.current.events).toHaveLength(2));
  expect(hook.result.current.events[0].kind).toBe("request");
  await new Promise((r) => setTimeout(r, 175));
  expect(invalidate).toHaveBeenCalledWith({ queryKey: ["clinic", "clinic-a"] });
  state.doctor = "doctor-b";
  hook.rerender();
  await waitFor(() => expect(hook.result.current.events).toHaveLength(0));
  hook.unmount();
  client.clear();
});
