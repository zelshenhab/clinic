import { it, expect, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { authenticate } from "../src/common/middleware/auth.js";
import { memberships } from "../src/modules/admin/permissions.js";
import { inFlight } from "../src/common/async/in-flight.js";
it("shares concurrent token verification but rechecks every later request", async () => {
  let complete: any;
  const getUser = vi.fn(
      () =>
        new Promise<any>((resolve) => {
          complete = resolve;
        }),
    ),
    db = { auth: { getUser } } as unknown as SupabaseClient;
  const a = authenticate(db, "Bearer same-token"),
    b = authenticate(db, "Bearer same-token");
  await Promise.resolve();
  expect(getUser).toHaveBeenCalledTimes(1);
  complete({ data: { user: { id: "actor" } }, error: null });
  await expect(Promise.all([a, b])).resolves.toHaveLength(2);
  getUser.mockResolvedValue({ data: { user: null }, error: { status: 401 } });
  await expect(authenticate(db, "Bearer same-token")).rejects.toThrow();
  expect(getUser).toHaveBeenCalledTimes(2);
});
it("never shares authorization work across credentials, clients, or failed requests", async () => {
  const a = {},
    b = {},
    task = vi.fn(async () => 1);
  await Promise.all([
    inFlight(a, "token-a", task),
    inFlight(a, "token-b", task),
    inFlight(b, "token-a", task),
  ]);
  expect(task).toHaveBeenCalledTimes(3);
  const fail = vi.fn(async () => {
    throw Error("offline");
  });
  await expect(inFlight(a, "failing", fail)).rejects.toThrow("offline");
  await expect(inFlight(a, "failing", fail)).rejects.toThrow("offline");
  expect(fail).toHaveBeenCalledTimes(2);
});
it("membership lookups are shared only while pending and immediately observe revocation afterwards", async () => {
  let finish: any;
  const read = vi.fn(
      () =>
        new Promise<any>((resolve) => {
          finish = resolve;
        }),
    ),
    query: any = {
      select: () => query,
      eq: (key: string) => (key === "active" ? read() : query),
    },
    db = { from: () => query } as unknown as SupabaseClient;
  const a = memberships(db, "actor"),
    b = memberships(db, "actor");
  await Promise.resolve();
  expect(read).toHaveBeenCalledTimes(1);
  finish({
    data: [{ id: "m", role: "DOCTOR", doctor_id: "d", clinic_id: "c" }],
    error: null,
  });
  expect((await a).length).toBe(1);
  await b;
  read.mockResolvedValue({ data: [], error: null });
  expect(await memberships(db, "actor")).toEqual([]);
  expect(read).toHaveBeenCalledTimes(2);
});
