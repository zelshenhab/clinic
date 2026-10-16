// Uses isolated browser-api.ts: real Node/SQL operations, controlled test-only Auth.
import { createRequire } from "node:module";
import assert from "node:assert/strict";
import { mkdirSync } from "node:fs";
const { chromium } = createRequire(import.meta.url)(
  process.env.PLAYWRIGHT_MODULE || "playwright-core",
);
const actor = "10000000-0000-4000-8000-000000000003",
  admin = "10000000-0000-4000-8000-000000000001";
const tokenFor = (id) =>
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
  Buffer.from(
    JSON.stringify({ sub: id, role: "authenticated", exp: 4102444800 }),
  ).toString("base64url") +
  ".testsignature";
const token = tokenFor(actor),
  headers = { Authorization: "Bearer " + token },
  user = {
    id: actor,
    aud: "authenticated",
    role: "authenticated",
    email: "doctor@example.invalid",
    app_metadata: { provider: "email" },
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
const browser = await chromium.launch({
    headless: true,
    executablePath:
      process.env.CHROME_PATH ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  }),
  page = await browser.newPage({ viewport: { width: 1440, height: 1000 } }),
  errors = [];
page.setDefaultTimeout(10000);
page.on("pageerror", (e) => errors.push(e.message));
await page.addInitScript(() => localStorage.setItem("language", "en"));
await page.route("http://127.0.0.1:54321/auth/v1/**", (route) =>
  route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify(
      route.request().url().includes("/user")
        ? user
        : {
            access_token: token,
            token_type: "bearer",
            expires_in: 3600,
            refresh_token: "test-only-refresh",
            user,
          },
    ),
  }),
);
mkdirSync("docs/verification", { recursive: true });
try {
  await page.goto("http://127.0.0.1:5178/login");
  await page.getByLabel("Email", { exact: true }).fill(user.email);
  await page.getByLabel("Password", { exact: true }).fill("test-only-password");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await page
    .getByRole("heading", { name: "Doctor overview", exact: true })
    .waitFor();
  await page.locator(".kpi-grid").waitFor();
  assert.equal(await page.locator("aside nav a").count(), 9);
  assert.equal(
    await page
      .locator("aside nav")
      .getByRole("link", { name: "Staff", exact: true })
      .count(),
    0,
  );
  await page.screenshot({
    path: "docs/verification/doctor-overview.png",
    fullPage: true,
  });
  for (const title of [
    "My appointments",
    "My calendar",
    "Arrival queue",
    "My patients",
    "My schedule",
    "Notifications",
    "My profile",
    "Settings",
  ]) {
    await page
      .locator("aside nav")
      .getByRole("link", { name: title, exact: true })
      .click();
    await page
      .getByRole("heading", { name: title, level: 1, exact: true })
      .waitFor();
    await page.locator(".skeleton").first().waitFor({ state: "hidden" });
    assert.equal(
      await page.locator(".failure").count(),
      0,
      title + " API error",
    );
  }
  await page
    .locator("aside nav")
    .getByRole("link", { name: "My calendar", exact: true })
    .click();
  for (const view of ["Day", "Week", "Month"])
    await page.getByRole("button", { name: view, exact: true }).click();
  await page.locator(".calendar-board.month").waitFor();
  await page
    .getByRole("heading", { name: "Current working schedule", exact: true })
    .waitFor();
  const clinic = await page
      .getByRole("combobox", { name: "Clinic", exact: true })
      .inputValue(),
    api = "http://127.0.0.1:3011/api/v1";
  const result = await page.request.get(api + "/doctor/appointments", {
    headers,
    params: { clinic_id: clinic },
  });
  assert.equal(result.status(), 200);
  const appointments = (await result.json()).data;
  assert.ok(appointments.items.length);
  await page
    .locator("aside nav")
    .getByRole("link", { name: "My appointments", exact: true })
    .click();
  await page
    .getByRole("button", { name: "View details", exact: true })
    .first()
    .click();
  await page
    .getByRole("button", { name: "Request rescheduling", exact: true })
    .click();
  let form = page.locator("form.confirmation");
  const future = new Date(Date.now() + 7 * 86400000);
  await form
    .locator('input[type="datetime-local"]')
    .fill(future.toISOString().slice(0, 16));
  await form.locator("textarea").fill("Please review a later appointment time");
  await form
    .getByRole("button", { name: "Submit request", exact: true })
    .click();
  await form.waitFor({ state: "hidden" });
  await page.getByRole("button", { name: "Close", exact: true }).click();
  await page
    .locator("aside nav")
    .getByRole("link", { name: "My schedule", exact: true })
    .click();
  let editor = page.locator("form.stack-form").first();
  await editor.locator('input[name="weekly.0.end"]').fill("18:15");
  const savedPromise = page.waitForResponse(
    (r) =>
      r.url().includes("/doctor/schedule") && r.request().method() === "PUT",
  );
  await editor.getByRole("button", { name: "Save", exact: true }).click();
  assert.equal((await savedPromise).status(), 200);
  await page
    .locator(".doctor-hours .shift-card")
    .filter({ hasText: "09:00–18:15" })
    .first()
    .waitFor();
  const me = (
    await (
      await page.request.get(api + "/doctor/me", {
        headers,
        params: { clinic_id: clinic },
      })
    ).json()
  ).data;
  const svc = appointments.items[0].service_id;
  let freeSlots = [],
    date = "";
  for (let offset = 1; offset < 8; offset++) {
    date = new Date(Date.now() + offset * 86400000).toISOString().slice(0, 10);
    const response = await page.request.get(
      api + "/clinics/" + clinic + "/availability",
      { params: { doctor_id: me.id, service_id: svc, date } },
    );
    assert.equal(response.status(), 200);
    freeSlots = (await response.json()).data;
    if (freeSlots.length) break;
  }
  assert.ok(freeSlots.length);
  const chosen = freeSlots[0].starts_at,
    patientHeaders = {
      Authorization:
        "Bearer " + tokenFor("10000000-0000-4000-8000-000000000002"),
    };
  const booked = await page.request.post(
    api + "/clinics/" + clinic + "/booking/appointments",
    {
      headers: patientHeaders,
      data: { doctor_id: me.id, service_id: svc, starts_at: chosen },
    },
  );
  assert.equal(booked.status(), 201);
  const available = (
    await (
      await page.request.get(api + "/clinics/" + clinic + "/availability", {
        params: { doctor_id: me.id, service_id: svc, date },
      })
    ).json()
  ).data;
  assert.ok(
    !available.some(
      (slot) => Date.parse(slot.starts_at) === Date.parse(chosen),
    ),
  );
  assert.equal(
    (
      await page.request.post(
        api + "/clinics/" + clinic + "/booking/appointments",
        {
          headers: patientHeaders,
          data: { doctor_id: me.id, service_id: svc, starts_at: chosen },
        },
      )
    ).status(),
    409,
  );
  const requests = (
    await (
      await page.request.get(api + "/doctor/requests", {
        headers,
        params: { clinic_id: clinic },
      })
    ).json()
  ).data;
  assert.equal(requests.items.length, 1);
  const reschedule = requests.items.find((r) => r.kind === "reschedule");
  const denied = await page.request.patch(
    api + "/admin/clinics/" + clinic + "/doctor-requests/" + reschedule.id,
    { headers, data: { approve: true, note: "" } },
  );
  assert.equal(denied.status(), 403);
  const reviewed = await page.request.patch(
    api + "/admin/clinics/" + clinic + "/doctor-requests/" + reschedule.id,
    {
      headers: { Authorization: "Bearer " + tokenFor(admin) },
      data: { approve: false, note: "Please choose an available slot" },
    },
  );
  assert.equal(reviewed.status(), 200);
  await page
    .locator("aside nav")
    .getByRole("link", { name: "Notifications", exact: true })
    .click();
  await page
    .getByRole("cell", { name: "Request rejected", exact: true })
    .waitFor();
  await page
    .getByRole("combobox", { name: "Clinic", exact: true })
    .selectOption({ index: 1 });
  await page.locator(".skeleton").first().waitFor({ state: "hidden" });
  await page
    .locator("aside nav")
    .getByRole("link", { name: "My patients", exact: true })
    .click();
  await page.locator(".skeleton").first().waitFor({ state: "hidden" });
  assert.equal(
    await page.getByRole("cell", { name: "QA Patient", exact: true }).count(),
    0,
  );
  await page.getByRole("button", { name: "RU", exact: true }).click();
  await page.getByRole("heading", { name: "Мои пациенты", level: 1 }).waitFor();
  await page.setViewportSize({ width: 390, height: 844 });
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth + 1,
    ),
  );
  await page.screenshot({
    path: "docs/verification/doctor-mobile.png",
    fullPage: true,
  });
  const adminPage = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
  });
  adminPage.setDefaultTimeout(10000);
  adminPage.on("pageerror", (e) => errors.push(e.message));
  await adminPage.addInitScript(() => localStorage.setItem("language", "en"));
  const adminUser = { ...user, id: admin, email: "qa@example.invalid" };
  await adminPage.route("http://127.0.0.1:54321/auth/v1/**", (route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(
        route.request().url().includes("/user")
          ? adminUser
          : {
              access_token: tokenFor(admin),
              token_type: "bearer",
              expires_in: 3600,
              refresh_token: "test-only-refresh",
              user: adminUser,
            },
      ),
    }),
  );
  await adminPage.goto("http://127.0.0.1:5178/login");
  await adminPage.getByLabel("Email", { exact: true }).fill(adminUser.email);
  await adminPage
    .getByLabel("Password", { exact: true })
    .fill("test-only-password");
  await adminPage.getByRole("button", { name: "Sign in", exact: true }).click();
  await adminPage
    .getByRole("heading", { name: "Overview", exact: true })
    .waitFor();
  await adminPage
    .getByRole("combobox", { name: "Clinic", exact: true })
    .selectOption(clinic);
  await adminPage
    .locator("aside nav")
    .getByRole("link", { name: "Schedules", exact: true })
    .click();
  await adminPage
    .getByRole("combobox", { name: "Request status", exact: true })
    .selectOption("rejected");
  await adminPage
    .getByRole("row")
    .filter({ hasText: "Please review a later appointment time" })
    .getByRole("button", { name: "View details", exact: true })
    .click();
  await adminPage.locator("dialog[open] .status.rejected").waitFor();
  await adminPage.getByRole("button", { name: "Close", exact: true }).click();
  await adminPage.close();
  assert.deepEqual(errors, []);
  console.log(
    "Doctor browser QA passed: private login/layout, 9 pages, calendar views/schedule, own patients, direct schedule save, public slots, patient booking, duplicate-booking rejection, reschedule request, admin-only review, notifications, clinic switch, RU/EN and mobile layout.",
  );
} catch (e) {
  await page.screenshot({
    path: "docs/verification/doctor-failure.png",
    fullPage: true,
  });
  console.error(await page.locator(".failure").allTextContents());
  throw e;
} finally {
  await browser.close();
}
