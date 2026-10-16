// Auth/API are controlled fixtures; this test exercises real Supabase browser session cleanup and React routing.
import { createRequire } from "node:module";
import assert from "node:assert/strict";
const { chromium } = createRequire(import.meta.url)(
  process.env.PLAYWRIGHT_MODULE || "playwright-core",
);
const browser = await chromium.launch({
  headless: true,
  executablePath:
    process.env.CHROME_PATH ||
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});
try {
  for (const mode of ["success", "unavailable", "slow"]) {
    const page = await browser.newPage();
    page.setDefaultTimeout(12000);
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.addInitScript(() => localStorage.setItem("language", "en"));
    let email = "doctor-a@example.invalid";
    const user = () => ({
      id: email.startsWith("doctor-a")
        ? "10000000-0000-4000-8000-000000000001"
        : "10000000-0000-4000-8000-000000000002",
      aud: "authenticated",
      role: "authenticated",
      email,
      app_metadata: { provider: "email" },
      user_metadata: {},
      created_at: new Date().toISOString(),
    });
    await page.route("http://127.0.0.1:54321/auth/v1/**", async (route) => {
      if (route.request().url().includes("/logout")) {
        if (mode === "slow") {
          await new Promise((r) => setTimeout(r, 6000));
          try {
            await route.fulfill({ status: 204 });
          } catch {}
          return;
        }
        return route.fulfill({
          status: mode === "success" ? 204 : 503,
          body:
            mode === "success"
              ? ""
              : JSON.stringify({ message: "Unavailable" }),
        });
      }
      const data = route.request().postDataJSON();
      if (data?.email) email = data.email;
      const u = user(),
        token =
          "eyJhbGciOiJIUzI1NiJ9." +
          Buffer.from(
            JSON.stringify({
              sub: u.id,
              role: "authenticated",
              exp: 4102444800,
            }),
          ).toString("base64url") +
          ".test";
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(
          route.request().url().includes("/user")
            ? u
            : {
                access_token: token,
                token_type: "bearer",
                refresh_token: "fixture",
                expires_in: 3600,
                user: u,
              },
        ),
      });
    });
    await page.route("http://127.0.0.1:3011/api/v1/**", (route) => {
      const path = new URL(route.request().url()).pathname;
      let data = {};
      if (path.endsWith("/admin/me"))
        data = {
          id: user().id,
          email,
          memberships: [
            {
              id: "m",
              role: "DOCTOR",
              doctor_id: "doctor-a",
              clinic_id: "clinic-a",
            },
          ],
        };
      else if (path.endsWith("/admin/clinics"))
        data = [
          {
            id: "clinic-a",
            name: { en: "Test clinic", ru: "Клиника" },
            timezone: "Europe/Moscow",
            active: true,
          },
        ];
      else if (path.endsWith("/doctor/dashboard"))
        data = {
          kpis: {
            today: 0,
            upcoming: 0,
            confirmed: 0,
            pending: 0,
            completed: 0,
            cancelled: 0,
            patients: 0,
          },
          today: [],
          next: null,
          daily: [],
          statuses: [],
          schedule: { weekly: [], exceptions: [] },
        };
      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ success: true, data }),
      });
    });
    const login = async (address) => {
      await page.getByLabel("Email", { exact: true }).fill(address);
      await page
        .getByLabel("Password", { exact: true })
        .fill("fixture-password");
      await page.getByRole("button", { name: "Sign in", exact: true }).click();
      await page
        .getByRole("heading", { name: "Doctor overview", exact: true })
        .waitFor();
    };
    await page.goto("http://127.0.0.1:5178/login");
    await login(email);
    await page.locator(".profile-button").click();
    await page.getByRole("button", { name: "Sign out", exact: true }).click();
    await page.waitForURL("**/login");
    await page.getByRole("button", { name: "Sign in", exact: true }).waitFor();
    assert.equal(
      await page.evaluate(() =>
        Object.keys(localStorage).some(
          (k) => k.includes("-auth-token") && !k.includes("code-verifier"),
        ),
      ),
      false,
      mode + " persisted session",
    );
    await page.reload();
    await page
      .getByRole("heading", { name: "Welcome back", exact: true })
      .waitFor();
    await login("doctor-b@example.invalid");
    assert.ok(
      (await page.locator(".profile-button").textContent()).includes(
        "doctor-b@example.invalid",
      ),
    );
    assert.deepEqual(errors, []);
    await page.close();
    console.log("Logout browser passed:", mode, "and account switch");
  }
} finally {
  await browser.close();
}
