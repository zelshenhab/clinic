import { it, expect, vi } from "vitest";
import request from "supertest";
import type { User } from "@supabase/supabase-js";
import { createApp } from "../src/app.js";
import { AuthenticationError } from "../src/common/errors/app-error.js";
const config = {
  NODE_ENV: "test" as const,
  PORT: 3000,
  CORS_ORIGINS: "http://localhost:5173",
  SUPABASE_URL: "http://localhost:54321",
  SUPABASE_ANON_KEY: "test",
  SUPABASE_SERVICE_ROLE_KEY: "test",
};
const clinics = {
  list: async () => [],
  get: async () => ({}),
  settings: async () => ({}),
};
const patients = {
  notifications: vi.fn(async () => []),
  profile: vi.fn(async () => null),
  update: vi.fn(async () => ({ full_name: "Demo" })),
  appointments: vi.fn(async () => []),
  familyMembers: vi.fn(async () => []),
  addFamilyMember: vi.fn(async () => ({ id: "member" })),
  updateFamilyMember: vi.fn(async () => ({ id: "member" })),
  removeFamilyMember: vi.fn(async () => {}),
};
const auth = {
  user: async (header?: string) => {
    if (header !== "Bearer valid") throw new AuthenticationError();
    return { id: "verified-user", phone: "+70000000000" } as User;
  },
  logout: vi.fn(async () => {}),
};
it("rejects expired/missing sessions for private data", async () => {
  const r = await request(createApp(config, clinics, { auth, patients })).get(
    "/api/v1/me/profile",
  );
  expect(r.status).toBe(401);
  expect(patients.profile).not.toHaveBeenCalled();
});
it("uses the verified identity and never accepts a client user ID", async () => {
  const app = createApp(config, clinics, { auth, patients });
  const r = await request(app)
    .patch("/api/v1/me/profile")
    .set("Authorization", "Bearer valid")
    .send({ full_name: "Demo", id: "other" });
  expect(r.status).toBe(400);
  const ok = await request(app)
    .patch("/api/v1/me/profile")
    .set("Authorization", "Bearer valid")
    .send({ full_name: "Demo" });
  expect(ok.status).toBe(200);
  expect(patients.update).toHaveBeenCalledWith("verified-user", {
    full_name: "Demo",
  });
});
it("scopes personal appointment reads by actual clinic UUID and verified identity", async () => {
  const id = "12a30244-3000-4000-8000-000000000001";
  const r = await request(createApp(config, clinics, { auth, patients }))
    .get("/api/v1/me/appointments")
    .query({ clinic_id: id })
    .set("Authorization", "Bearer valid");
  expect(r.status).toBe(200);
  expect(patients.appointments).toHaveBeenCalledWith("verified-user", id);
});

it("requires verified identity and clinic UUID for notifications", async () => {
  const id = "12a30244-3000-4000-8000-000000000001";
  const app = createApp(config, clinics, { auth, patients });
  expect(
    (
      await request(app)
        .get("/api/v1/me/notifications")
        .query({ clinic_id: id })
    ).status,
  ).toBe(401);
  const r = await request(app)
    .get("/api/v1/me/notifications")
    .query({ clinic_id: id })
    .set("Authorization", "Bearer valid");
  expect(r.status).toBe(200);
  expect(patients.notifications).toHaveBeenCalledWith("verified-user", id);
});

it("manages family members only for the verified account with validated input", async () => {
  const app = createApp(config, clinics, { auth, patients });
  expect((await request(app).get("/api/v1/me/family-members")).status).toBe(401);
  const bad = await request(app)
    .post("/api/v1/me/family-members")
    .set("Authorization", "Bearer valid")
    .send({ full_name: "Child", relationship: "pet", owner_id: "other" });
  expect(bad.status).toBe(400);
  expect(patients.addFamilyMember).not.toHaveBeenCalled();
  const future = await request(app)
    .post("/api/v1/me/family-members")
    .set("Authorization", "Bearer valid")
    .send({ full_name: "Child", relationship: "child", date_of_birth: "2999-01-01" });
  expect(future.status).toBe(400);
  const created = await request(app)
    .post("/api/v1/me/family-members")
    .set("Authorization", "Bearer valid")
    .send({ full_name: " Child ", relationship: "child", date_of_birth: "2020-05-01" });
  expect(created.status).toBe(201);
  expect(patients.addFamilyMember).toHaveBeenCalledWith("verified-user", {
    full_name: "Child",
    relationship: "child",
    date_of_birth: "2020-05-01",
  });
  const id = "12a30244-3000-4000-8000-000000000002";
  expect(
    (
      await request(app)
        .patch("/api/v1/me/family-members/" + id)
        .set("Authorization", "Bearer valid")
        .send({ full_name: "Mother", relationship: "parent" })
    ).status,
  ).toBe(200);
  expect(patients.updateFamilyMember).toHaveBeenCalledWith("verified-user", id, {
    full_name: "Mother",
    relationship: "parent",
  });
  expect(
    (
      await request(app)
        .delete("/api/v1/me/family-members/not-a-uuid")
        .set("Authorization", "Bearer valid")
    ).status,
  ).toBe(400);
  expect(
    (
      await request(app)
        .delete("/api/v1/me/family-members/" + id)
        .set("Authorization", "Bearer valid")
    ).status,
  ).toBe(200);
  expect(patients.removeFamilyMember).toHaveBeenCalledWith("verified-user", id);
});
