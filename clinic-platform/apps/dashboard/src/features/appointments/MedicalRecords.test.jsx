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
import MedicalRecords from "./MedicalRecords";
let access = { role: "CLINIC_ADMIN" };
vi.mock("../../contexts/ClinicContext", () => ({
  useClinic: () => ({
    clinic: { id: "clinic-a", timezone: "Europe/Moscow" },
    access,
  }),
}));
vi.mock("../../services/api", () => ({
  adminPath: (id, path) => "/admin/clinics/" + id + "/" + path,
  api: { get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
const view = () =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <LocaleProvider>
        <ToastProvider>
          <MedicalRecords patientId="patient-1" />
        </ToastProvider>
      </LocaleProvider>
    </QueryClientProvider>,
  );
const record = {
  id: "record-1",
  title: "Fictional blood test",
  kind: "lab_result",
  family_member_name: "Fictional child",
  doctor_name: { en: "Test doctor" },
  created_at: "2026-10-20T06:00:00Z",
};
it("uploads a document through clinic routes and opens a signed download", async () => {
  localStorage.setItem("language", "en");
  access = { role: "CLINIC_ADMIN" };
  api.get.mockImplementation(async (path) =>
    path.endsWith("/download")
      ? { url: "https://example.invalid/signed" }
      : [record],
  );
  api.post.mockResolvedValue({ id: "record-2" });
  const opened = vi.spyOn(window, "open").mockImplementation(() => null);
  view();
  expect(await screen.findByText("Fictional blood test")).toBeTruthy();
  expect(screen.getByText("Fictional child")).toBeTruthy();
  expect(api.get).toHaveBeenCalledWith(
    "/admin/clinics/clinic-a/patients/patient-1/medical-records",
    expect.objectContaining({ params: undefined }),
  );
  fireEvent.change(screen.getByLabelText("Document title"), {
    target: { value: "MRI" },
  });
  fireEvent.change(screen.getByLabelText("Document type"), {
    target: { value: "imaging" },
  });
  const file = new File(["%PDF-1.7"], "mri.pdf", { type: "application/pdf" });
  fireEvent.change(screen.getByLabelText(/PDF, JPEG or PNG/), {
    target: { files: [file] },
  });
  fireEvent.click(screen.getByText("Upload document"));
  await waitFor(() => expect(api.post).toHaveBeenCalled());
  const [path, form] = api.post.mock.calls[0];
  expect(path).toBe(
    "/admin/clinics/clinic-a/patients/patient-1/medical-records",
  );
  expect(form.get("title")).toBe("MRI");
  expect(form.get("kind")).toBe("imaging");
  expect(form.get("file").name).toBe("mri.pdf");
  fireEvent.click(screen.getByText("Open"));
  await waitFor(() =>
    expect(opened).toHaveBeenCalledWith(
      "https://example.invalid/signed",
      "_blank",
      "noopener",
    ),
  );
});
it("doctors use their own workspace routes scoped by clinic", async () => {
  localStorage.setItem("language", "en");
  access = { role: "DOCTOR", doctor_id: "doc" };
  api.get.mockResolvedValue([]);
  view();
  await waitFor(() =>
    expect(api.get).toHaveBeenCalledWith(
      "/doctor/patients/patient-1/medical-records",
      expect.objectContaining({ params: { clinic_id: "clinic-a" } }),
    ),
  );
});
