import { it, expect, vi, beforeEach } from "vitest";
const auth = vi.hoisted(() => ({
  getSession: vi.fn(),
  refreshSession: vi.fn(),
  signOut: vi.fn(async () => ({ error: null })),
}));
vi.mock("./supabase", () => ({ supabase: { auth } }));
import { api } from "./api";
beforeEach(() => {
  vi.clearAllMocks();
  auth.getSession.mockResolvedValue({
    data: { session: { access_token: "token" } },
  });
});
function unauthorized(config) {
  return Promise.reject({
    config,
    response: { status: 401, data: { error: { code: "UNAUTHORIZED" } } },
  });
}
it("refreshes a rejected token once and retries with verified session identity", async () => {
  auth.refreshSession.mockResolvedValue({
    data: { session: { access_token: "fresh" } },
    error: null,
  });
  let calls = 0;
  const result = await api.get("/admin/me", {
    adapter: (config) => {
      expect(config.headers.Authorization).toBe("Bearer token");
      return ++calls === 1
        ? unauthorized(config)
        : Promise.resolve({
            config,
            data: { success: true, data: { id: "staff" } },
            status: 200,
          });
    },
  });
  expect(result).toEqual({ id: "staff" });
  expect(calls).toBe(2);
  expect(auth.refreshSession).toHaveBeenCalledTimes(1);
});
it("expires local sessions when refresh fails without endless mutation retries", async () => {
  auth.refreshSession.mockResolvedValue({
    data: { session: null },
    error: Error("expired"),
  });
  await expect(
    api.post("/admin/clinics/a/appointments", {}, { adapter: unauthorized }),
  ).rejects.toMatchObject({ code: "UNAUTHORIZED", status: 401 });
  expect(auth.signOut).toHaveBeenCalledWith({ scope: "local" });
  expect(auth.refreshSession).toHaveBeenCalledTimes(1);
});
it("rejects private requests before dispatch when no session exists", async () => {
  auth.getSession.mockResolvedValue({ data: { session: null } });
  const adapter = vi.fn();
  await expect(api.get("/admin/me", { adapter })).rejects.toMatchObject({
    status: 401,
  });
  expect(adapter).not.toHaveBeenCalled();
});
