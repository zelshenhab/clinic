// Compare previous/current UI using identical controlled 600 ms business reads; no live-patient data.
import { createRequire } from "node:module";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
const { chromium } = createRequire(import.meta.url)(
  process.env.PLAYWRIGHT_MODULE || "playwright-core",
);
const browser = await chromium.launch({
    headless: true,
    executablePath:
      process.env.CHROME_PATH ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  }),
  results = {};
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
try {
  for (const [name, port] of [
    ["before", 5179],
    ["after", 5178],
  ]) {
    const page = await browser.newPage({
      viewport: { width: 1440, height: 1000 },
    });
    page.setDefaultTimeout(12000);
    const errors = [],
      calls = { doctors: 0 };
    page.on("pageerror", (e) => errors.push(e.message));
    await page.addInitScript(() => localStorage.setItem("language", "en"));
    const user = {
        id: "10000000-0000-4000-8000-000000000001",
        aud: "authenticated",
        role: "authenticated",
        email: "perf@example.invalid",
        app_metadata: { provider: "email" },
        user_metadata: {},
        created_at: new Date().toISOString(),
      },
      token =
        "eyJhbGciOiJIUzI1NiJ9." +
        Buffer.from(
          JSON.stringify({
            sub: user.id,
            role: "authenticated",
            exp: 4102444800,
          }),
        ).toString("base64url") +
        ".test";
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
                refresh_token: "fixture",
                expires_in: 3600,
                user,
              },
        ),
      }),
    );
    await page.route("http://127.0.0.1:3011/api/v1/**", async (route) => {
      const url = new URL(route.request().url()),
        path = url.pathname;
      let data = {};
      if (path.endsWith("/admin/me"))
        data = {
          id: user.id,
          email: user.email,
          memberships: [
            { id: "m", role: "CLINIC_ADMIN", clinic_id: "clinic-a" },
          ],
        };
      else if (path.endsWith("/admin/clinics"))
        data = [
          {
            id: "clinic-a",
            name: { en: "Performance clinic", ru: "Клиника" },
            timezone: "Europe/Moscow",
            active: true,
          },
        ];
      else if (path.endsWith("/dashboard"))
        data = {
          kpis: {
            today: 0,
            upcoming: 0,
            pending: 0,
            confirmed: 0,
            completed: 0,
            cancelled: 0,
            doctors: 1,
            patients: 0,
          },
          daily: [],
          monthly: [],
          statuses: [],
          specialties: [],
          services: [],
          workload: [],
          today: [],
          recent: [],
          upcoming: [],
        };
      else if (path.endsWith("/options"))
        data = { doctors: [], services: [], specialties: [] };
      else if (path.endsWith("/doctors")) {
        calls.doctors++;
        const number = Number(url.searchParams.get("page") || 1);
        data = {
          items: [
            {
              id: "doctor-" + number,
              name: { en: "Doctor page " + number, ru: "Врач " + number },
              active: true,
              specialties: [],
              experience_years: 10,
              starting_price_rub: 2000,
            },
          ],
          pagination: {
            page: number,
            limit: 20,
            total: 40,
            hasMore: number === 1,
          },
        };
        await delay(600);
      } else if (path.endsWith("/services")) {
        data = {
          items: [],
          pagination: { page: 1, limit: 20, total: 0, hasMore: false },
        };
        await delay(600);
      }
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ success: true, data }),
      });
    });
    await page.goto(`http://127.0.0.1:${port}/login`);
    await page.getByLabel("Email", { exact: true }).fill(user.email);
    await page.getByLabel("Password", { exact: true }).fill("fixture-password");
    await page.getByRole("button", { name: "Sign in", exact: true }).click();
    await page.locator(".kpi-grid").waitFor();
    const doctors = page
      .locator("aside nav")
      .getByRole("link", { name: "Doctors", exact: true });
    await doctors.hover();
    await delay(800);
    const start = performance.now();
    await doctors.click();
    await page.getByText("Doctor page 1", { exact: true }).waitFor();
    const clickMs = Math.round(performance.now() - start);
    await page.locator(".pagination button").last().click();
    const retainsRows = await page
      .getByText("Doctor page 1", { exact: true })
      .isVisible();
    await page.getByText("Doctor page 2", { exact: true }).waitFor();
    // A 31-second wall-clock jump makes the old 20-second catalog policy stale, without waiting in real time.
    await page.clock.install();
    await page.clock.setFixedTime(new Date(Date.now() + 31000));
    const services = page
      .locator("aside nav")
      .getByRole("link", { name: "Services", exact: true });
    await services.click();
    await page
      .getByRole("heading", { name: "Services", level: 1, exact: true })
      .waitFor();
    await page.locator(".skeleton").first().waitFor({ state: "hidden" });
    const beforeReturn = calls.doctors;
    await doctors.click();
    await page.getByText("Doctor page 1", { exact: true }).waitFor();
    await delay(800);
    const revisitRequests = calls.doctors - beforeReturn;
    results[name] = {
      clickToRowsMs: clickMs,
      paginationKeepsRows: retainsRows,
      catalogRevisitRequests: revisitRequests,
    };
    assert.deepEqual(errors, []);
    await page.close();
  }
  assert.ok(
    results.after.clickToRowsMs < results.before.clickToRowsMs - 250,
    JSON.stringify(results),
  );
  assert.equal(results.after.paginationKeepsRows, true);
  assert.equal(results.after.catalogRevisitRequests, 0);
  writeFileSync(
    "docs/verification/performance.json",
    JSON.stringify(
      {
        fixture: "600ms API delay, 800ms pointer intent, 31s wall-clock jump",
        results,
      },
      null,
      2,
    ) + "\n",
  );
  console.log(JSON.stringify(results));
} finally {
  await browser.close();
}
