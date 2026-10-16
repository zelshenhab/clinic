import { it, expect, vi } from "vitest";
import { authFetch } from "./supabase";
it("bounds a stalled logout request and aborts its transport", async () => {
  vi.useFakeTimers();
  const original = globalThis.fetch;
  globalThis.fetch = vi.fn(
    (_url, init) =>
      new Promise((_resolve, reject) =>
        init.signal.addEventListener("abort", () =>
          reject(new DOMException("Aborted", "AbortError")),
        ),
      ),
  );
  try {
    const result = authFetch(
      "https://example.supabase.co/auth/v1/logout?scope=local",
      { method: "POST" },
    );
    const failed = expect(result).rejects.toMatchObject({ name: "AbortError" });
    await vi.advanceTimersByTimeAsync(4000);
    await failed;
    expect(globalThis.fetch.mock.calls[0][1].signal.aborted).toBe(true);
  } finally {
    globalThis.fetch = original;
    vi.useRealTimers();
  }
});
it("leaves normal auth requests on the original fetch path", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = vi.fn(async () => ({ status: 200 }));
  try {
    const init = { method: "POST" };
    await authFetch("https://example.supabase.co/auth/v1/token", init);
    expect(globalThis.fetch).toHaveBeenCalledWith(
      "https://example.supabase.co/auth/v1/token",
      init,
    );
  } finally {
    globalThis.fetch = original;
  }
});
