// @vitest-environment jsdom
import { it, expect, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ClinicProvider, useClinic } from "./ClinicContext";
vi.mock("./AuthContext", () => ({
  useAuth: () => ({
    staff: {
      id: "staff-a",
      memberships: [{ id: "membership", role: "SUPER_ADMIN", clinic_id: null }],
    },
  }),
}));
vi.mock("../services/api", () => ({
  api: {
    get: vi.fn(async () => [
      { id: "a", active: true },
      { id: "b", active: true },
    ]),
  },
}));
function Switch() {
  const { clinic, select } = useClinic();
  return (
    <>
      <span>{clinic?.id || "waiting"}</span>
      <button onClick={() => select("b")}>switch</button>
      <button onClick={() => select("unauthorized")}>invalid</button>
    </>
  );
}
it("removes previous clinic data and refuses unauthorized persisted selections", async () => {
  localStorage.clear();
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  client.setQueryData(
    ["clinic", "a", "patients"],
    [{ full_name: "Private test fixture" }],
  );
  render(
    <QueryClientProvider client={client}>
      <ClinicProvider>
        <Switch />
      </ClinicProvider>
    </QueryClientProvider>,
  );
  await screen.findByText("a");
  fireEvent.click(screen.getByText("switch"));
  await screen.findByText("b");
  expect(client.getQueryData(["clinic", "a", "patients"])).toBeUndefined();
  expect(localStorage.getItem("staff-clinic:staff-a")).toBe("b");
  fireEvent.click(screen.getByText("invalid"));
  await waitFor(() => expect(screen.getByText("b")).toBeTruthy());
  client.clear();
});
