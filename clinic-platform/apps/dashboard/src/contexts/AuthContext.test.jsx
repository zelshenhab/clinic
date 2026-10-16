// @vitest-environment jsdom
import { beforeEach, it, expect, vi } from "vitest";
import { renderHook, waitFor, act, cleanup } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider, useAuth } from "./AuthContext";
const state = vi.hoisted(() => ({
  listener: null,
  restore: vi.fn(),
  signOut: vi.fn(),
  clear: vi.fn(),
  login: vi.fn(),
}));
vi.mock("../services/supabase", () => ({
  clearStoredSession: state.clear,
  supabase: {
    auth: {
      getSession: state.restore,
      signOut: state.signOut,
      signInWithPassword: state.login,
      onAuthStateChange: (fn) => {
        state.listener = fn;
        return { data: { subscription: { unsubscribe: vi.fn() } } };
      },
    },
  },
}));
vi.mock("../services/api", () => ({
  api: {
    get: vi.fn(async () => ({
      id: "admin-a",
      memberships: [{ role: "SUPER_ADMIN" }],
    })),
  },
}));
beforeEach(() => {
  cleanup();
  vi.clearAllMocks();
  state.restore.mockResolvedValue({
    data: { session: { user: { id: "admin-a" }, access_token: "token-a" } },
  });
  state.signOut.mockResolvedValue({ error: null });
  state.login.mockResolvedValue({ error: null });
});
function fixture() {
  const client = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    }),
    wrapper = ({ children }) => (
      <QueryClientProvider client={client}>
        <AuthProvider>{children}</AuthProvider>
      </QueryClientProvider>
    );
  const hook = renderHook(() => useAuth(), { wrapper });
  return { client, hook };
}
it("logout clears session and cached private data even without an SDK signed-out callback", async () => {
  const { client, hook } = fixture();
  await waitFor(() => expect(hook.result.current.staff?.id).toBe("admin-a"));
  client.setQueryData(["clinic", "a", "patients"], { private: "old-patient" });
  await act(() => hook.result.current.logout());
  expect(state.signOut).toHaveBeenCalledWith({ scope: "local" });
  expect(state.clear).toHaveBeenCalledOnce();
  expect(hook.result.current.session).toBeNull();
  expect(hook.result.current.staff).toBeUndefined();
  expect(client.getQueryData(["clinic", "a", "patients"])).toBeUndefined();
  expect(hook.result.current.loggingOut).toBe(false);
  hook.unmount();
  client.clear();
});
it("failed remote revocation still clears local credentials and permits another account", async () => {
  state.signOut.mockRejectedValue(new Error("offline"));
  const { client, hook } = fixture();
  await waitFor(() => expect(hook.result.current.staff).toBeDefined());
  await act(() => hook.result.current.logout());
  expect(state.clear).toHaveBeenCalledOnce();
  expect(hook.result.current.session).toBeNull();
  act(() =>
    state.listener("SIGNED_IN", {
      user: { id: "doctor-b" },
      access_token: "token-b",
    }),
  );
  await waitFor(() =>
    expect(hook.result.current.session?.user.id).toBe("doctor-b"),
  );
  expect(client.getQueryData(["staff", "admin-a"])).toBeUndefined();
  hook.unmount();
  client.clear();
});
it("deduplicates repeated logout clicks and ignores a late restored session", async () => {
  let restore, finish;
  state.restore.mockImplementation(
    () =>
      new Promise((resolve) => {
        restore = resolve;
      }),
  );
  state.signOut.mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const { client, hook } = fixture();
  let first, second;
  act(() => {
    first = hook.result.current.logout();
    second = hook.result.current.logout();
  });
  expect(first).toBe(second);
  expect(state.signOut).toHaveBeenCalledOnce();
  expect(hook.result.current.loggingOut).toBe(true);
  await act(async () => {
    finish({ error: null });
    await first;
    restore({ data: { session: { user: { id: "admin-a" } } } });
  });
  expect(hook.result.current.session).toBeNull();
  expect(hook.result.current.staff).toBeUndefined();
  hook.unmount();
  client.clear();
});
