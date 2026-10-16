// Uses the isolated browser-api.ts SQL fixture and controlled test-only Auth.
import { createRequire } from "node:module";
import assert from "node:assert/strict";
const { chromium } = createRequire(import.meta.url)(
  process.env.PLAYWRIGHT_MODULE || "playwright-core",
);
const base = "http://127.0.0.1:3011/api/v1",
  web = "http://127.0.0.1:5178";
const admin = "10000000-0000-4000-8000-000000000001",
  doctor = "10000000-0000-4000-8000-000000000003";
const token = (id) =>
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
  Buffer.from(
    JSON.stringify({ sub: id, role: "authenticated", exp: 4102444800 }),
  ).toString("base64url") +
  ".testsignature";
async function call(path, { actor = admin, method = "GET", data } = {}) {
  const response = await fetch(base + path, {
    method,
    headers: {
      Authorization: "Bearer " + token(actor),
      "Content-Type": "application/json",
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  });
  const json = await response.json();
  assert.equal(response.ok, true, JSON.stringify(json));
  return json.data;
}
const browser = await chromium.launch({
  headless: true,
  executablePath:
    process.env.CHROME_PATH ||
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});
const errors = [];
async function login(id) {
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
  });
  page.on("pageerror", (e) => errors.push(e.message));
  const user = {
    id,
    aud: "authenticated",
    role: "authenticated",
    email: id === admin ? "qa@example.invalid" : "doctor@example.invalid",
    app_metadata: { provider: "email" },
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
  await page.addInitScript(() => localStorage.setItem("language", "en"));
  await page.route("http://127.0.0.1:54321/auth/v1/**", (route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(
        route.request().url().includes("/user")
          ? user
          : {
              access_token: token(id),
              token_type: "bearer",
              expires_in: 3600,
              refresh_token: "test-only",
              user,
            },
      ),
    }),
  );
  page.on("dialog", (dialog) => dialog.accept());
  await page.goto(web + "/login");
  await page.getByLabel("Email", { exact: true }).fill(user.email);
  await page.getByLabel("Password", { exact: true }).fill("test-only-password");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await page.locator("aside nav").waitFor();
  return page;
}
try {
  const page = await login(admin),
    c = await page.locator(".clinic-switch select").inputValue();
  await page
    .locator("aside nav")
    .getByRole("link", { name: "Clinic settings", exact: true })
    .click();
  await page
    .getByRole("heading", { name: "Cancellation and rescheduling policy" })
    .waitFor();
  const policy = page
    .locator("form")
    .filter({
      has: page.getByRole("heading", {
        name: "Cancellation and rescheduling policy",
      }),
    });
  await policy
    .getByLabel("Cancellation: minimum notice (minutes)", { exact: true })
    .fill("90");
  await policy
    .getByLabel("Rescheduling: minimum notice (minutes)", { exact: true })
    .fill("180");
  await Promise.all([
    page.waitForResponse(
      (r) =>
        r.url().endsWith("/booking-policy") &&
        r.request().method() === "PATCH" &&
        r.status() === 200,
    ),
    policy.getByRole("button", { name: "Save", exact: true }).click(),
  ]);
  assert.deepEqual(await call(`/clinics/${c}/booking-policy`), {
    cancellation_notice_minutes: 90,
    reschedule_notice_minutes: 180,
  });
  const appointments = await call(`/admin/clinics/${c}/appointments?limit=100`);
  let a = appointments.items.find(
    (a) => a.status === "pending" && a.attendance_status === "scheduled",
  );
  assert.ok(a);
  a = await call(`/admin/clinics/${c}/appointments/${a.id}`, {
    method: "PATCH",
    data: { status: "confirmed", expected_updated_at: a.updated_at },
  });
  const clinic = (await call("/admin/clinics")).find((x) => x.id === c),
    day = new Intl.DateTimeFormat("en-CA", {
      timeZone: clinic.timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date(a.starts_at));
  await page
    .locator("aside nav")
    .getByRole("link", { name: "Arrival queue", exact: true })
    .click();
  await page
    .getByRole("heading", { name: "Arrival queue", exact: true })
    .waitFor();
  await page.getByLabel("Date", { exact: true }).fill(day);
  let row = page.locator(`[data-appointment-id="${a.id}"]`);
  await row.getByRole("button", { name: "Arrived", exact: true }).click();
  await row.getByRole("button", { name: "Waiting", exact: true }).waitFor();
  await row.getByRole("button", { name: "Waiting", exact: true }).click();
  await page.getByText("Waiting", { exact: true }).first().waitFor();
  assert.equal(
    (await call(`/admin/clinics/${c}/appointments/${a.id}`)).attendance_status,
    "waiting",
  );
  const own = await login(doctor);
  await own
    .locator("aside nav")
    .getByRole("link", { name: "My schedule", exact: true })
    .click();
  await own.getByRole("heading", { name: "Schedule tools" }).waitFor();
  const now = new Date(),
    target = new Date(now);
  target.setUTCDate(target.getUTCDate() + 35);
  const date = target.toISOString().slice(0, 10);
  await own.getByLabel("Target week", { exact: true }).fill(date);
  await Promise.all([
    own.waitForResponse(
      (r) => r.url().endsWith("/schedule/copy") && r.status() === 200,
    ),
    own.getByRole("button", { name: "Copy week", exact: true }).click(),
  ]);
  const off = new Date(now);
  off.setUTCDate(off.getUTCDate() + 45);
  await own
    .getByLabel("Day off", { exact: true })
    .fill(off.toISOString().slice(0, 10));
  await Promise.all([
    own.waitForResponse(
      (r) => r.url().endsWith("/schedule/block") && r.status() === 200,
    ),
    own.getByRole("button", { name: "Block day", exact: true }).click(),
  ]);
  await own
    .locator("aside nav")
    .getByRole("link", { name: "Arrival queue", exact: true })
    .click();
  await own
    .getByRole("heading", { name: "Arrival queue", exact: true })
    .waitFor();
  await own.locator(".skeleton").first().waitFor({ state: "hidden" });
  assert.equal(await own.locator(".failure").count(), 0);
  const publicTimes = await call(`/clinics/${c}/next-available?limit=3`);
  assert.ok(publicTimes.items.length > 0);
  assert.ok(publicTimes.specialties.length > 0);
  assert.deepEqual(errors, []);
  console.log(
    "Patient experience browser QA passed: policy editing/public read, confirmed appointment arrival/waiting, doctor copy-week/day-off controls, own queue and nearest public times.",
  );
} finally {
  await browser.close();
}
