// @vitest-environment jsdom
import { it, expect, vi, afterEach } from "vitest";
import {
  render,
  screen,
  fireEvent,
  waitFor,
  cleanup,
} from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { LocaleProvider } from "../../contexts/LocaleContext";
import { ToastProvider } from "../../contexts/ToastContext";
import { api } from "../../services/api";
import BookingForm from "./BookingForm";
vi.mock("../../contexts/ClinicContext", () => ({
  useClinic: () => ({ clinic: { id: "clinic-a", timezone: "Europe/Moscow" } }),
}));
vi.mock("../../services/api", () => ({
  adminPath: (id, path) => "/admin/clinics/" + id + "/" + path,
  api: { get: vi.fn(), post: vi.fn(), patch: vi.fn() },
}));
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
it("fetches availability from Node and submits the exact server-provided UTC slot", async () => {
  localStorage.setItem("language", "en");
  const slot = "2026-10-20T06:00:00Z",
    onDone = vi.fn();
  api.get.mockImplementation(async (path) =>
    path.endsWith("/options")
      ? {
          doctors: [{ id: "doc", name: { en: "Test doctor" } }],
          services: [
            {
              id: "service",
              name: { en: "Consultation" },
              price_rub: 2000,
              doctor_ids: ["doc"],
            },
          ],
        }
      : path.endsWith("/patients")
        ? {
            items: [
              {
                id: "patient",
                full_name: "Test patient",
                phone: "+70000000000",
              },
            ],
          }
        : [{ starts_at: slot, ends_at: "2026-10-20T06:30:00Z" }],
  );
  let finish;
  api.post.mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  render(
    <QueryClientProvider client={client}>
      <LocaleProvider>
        <ToastProvider>
          <BookingForm onDone={onDone} />
        </ToastProvider>
      </LocaleProvider>
    </QueryClientProvider>,
  );
  await screen.findByLabelText("Patient");
  fireEvent.change(screen.getByLabelText("Patient"), {
    target: { value: "patient" },
  });
  fireEvent.change(screen.getByLabelText("Doctor"), {
    target: { value: "doc" },
  });
  fireEvent.change(screen.getByLabelText("Service"), {
    target: { value: "service" },
  });
  const choices = await screen.findByLabelText("Available times");
  expect(
    api.get.mock.calls.some(
      ([path, config]) =>
        path.endsWith("/availability") &&
        config.params.doctor_id === "doc" &&
        config.params.service_id === "service",
    ),
  ).toBe(true);
  fireEvent.change(choices, { target: { value: slot } });
  fireEvent.click(screen.getByRole("button", { name: "Create appointment" }));
  await waitFor(() =>
    expect(api.post).toHaveBeenCalledWith(
      "/admin/clinics/clinic-a/appointments",
      {
        patient_id: "patient",
        doctor_id: "doc",
        service_id: "service",
        starts_at: slot,
      },
    ),
  );
  expect(onDone).not.toHaveBeenCalled();
  finish({ id: "created" });
  await waitFor(() => expect(onDone).toHaveBeenCalled());
  client.clear();
});

it("reschedules without requiring changes to fixed disabled doctor and service fields", async () => {
  localStorage.setItem("language", "en");
  const existing = {
      id: "record",
      doctor_id: "doc",
      service_id: "service",
      patient_id: "patient",
      updated_at: "2026-10-12T09:00:00Z",
    },
    slot = "2026-10-20T06:30:00Z",
    done = vi.fn();
  api.get.mockImplementation(async (path) =>
    path.endsWith("/options")
      ? {
          doctors: [{ id: "doc", name: { en: "Test doctor" } }],
          services: [
            {
              id: "service",
              name: { en: "Consultation" },
              doctor_ids: ["doc"],
              price_rub: 2000,
            },
          ],
        }
      : [{ starts_at: slot, ends_at: "2026-10-20T07:00:00Z" }],
  );
  api.patch.mockResolvedValue({ id: "record", starts_at: slot });
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  render(
    <QueryClientProvider client={client}>
      <LocaleProvider>
        <ToastProvider>
          <BookingForm existing={existing} onDone={done} />
        </ToastProvider>
      </LocaleProvider>
    </QueryClientProvider>,
  );
  fireEvent.change(await screen.findByLabelText("Available times"), {
    target: { value: slot },
  });
  fireEvent.click(screen.getByRole("button", { name: "Reschedule" }));
  await waitFor(() =>
    expect(api.patch).toHaveBeenCalledWith(
      "/admin/clinics/clinic-a/appointments/record",
      { starts_at: slot, expected_updated_at: existing.updated_at },
    ),
  );
  await waitFor(() => expect(done).toHaveBeenCalled());
  client.clear();
});
