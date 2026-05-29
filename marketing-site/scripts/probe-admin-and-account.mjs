// Verify both deliverables for tonight's batch.
//
//   1. /pl/admin/users/ ORGANIZACJA column shows org legal names
//      (or "—") instead of raw UUIDs.
//   2. /pl/account/ guard renders without infinite loop / crashes
//      and shows the section scaffolding.
//
// Requires an env var ADMIN_EMAIL + ADMIN_PASSWORD to sign in as
// the SUPERWIZOR_ADMIN. If not set we skip the auth-gated checks
// and just verify the page shells load.

import { chromium } from "@playwright/test";
import { mkdir } from "node:fs/promises";

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "";

const EVIDENCE = "./evidence/admin-and-account";
await mkdir(EVIDENCE, { recursive: true });

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const page = await ctx.newPage();
const consoleErrors = [];
page.on("console", (m) => { if (m.type() === "error") consoleErrors.push(m.text().slice(0, 200)); });

const results = {};

// 1. Hit /pl/admin/ signed-out → expect sign-in form.
await page.goto("https://superwizor.web.app/pl/admin/", { waitUntil: "networkidle" });
await page.waitForTimeout(2000);
results.adminSignedOut = {
  has_email_input: await page.locator('input[type="email"]').count(),
  has_password_input: await page.locator('input[type="password"]').count(),
};

// 2. Hit /pl/account/ signed-out → expect redirect to /pl/login/
await page.goto("https://superwizor.web.app/pl/account/", { waitUntil: "networkidle" });
await page.waitForTimeout(3500);
results.accountSignedOut = {
  final_url: page.url(),
};

// 3. If creds are provided, sign in via the admin form and inspect users list.
if (ADMIN_EMAIL && ADMIN_PASSWORD) {
  await page.goto("https://superwizor.web.app/pl/admin/users/", { waitUntil: "networkidle" });
  await page.waitForTimeout(2000);
  await page.locator('input[type="email"]').fill(ADMIN_EMAIL);
  await page.locator('input[type="password"]').fill(ADMIN_PASSWORD);
  await page.locator('button[type="submit"]').click();
  // Wait for users table.
  await page.waitForSelector("table tbody tr", { timeout: 25000 });
  await page.waitForTimeout(2500); // give the orgNames lookup a beat
  await page.screenshot({ path: `${EVIDENCE}/03-admin-users.png`, fullPage: true });

  // Inspect the ORGANIZACJA column (4th td) — sample first 5 rows.
  const orgCells = await page.$$eval("table tbody tr", (rows) =>
    rows.slice(0, 5).map((r) => {
      const tds = r.querySelectorAll("td");
      return tds[3]?.textContent?.trim() ?? "";
    }),
  );
  results.orgColumnSample = orgCells;
  results.orgColumnLooksLikeUUIDs = orgCells.filter((s) => /^[0-9a-f]{8}-/.test(s)).length;

  // Now visit /pl/account/ signed-in (admin actually goes to admin
  // on login, but visiting account directly should still work — it
  // just shows the admin's own profile/org).
  await page.goto("https://superwizor.web.app/pl/account/", { waitUntil: "networkidle" });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: `${EVIDENCE}/04-account-admin.png`, fullPage: true });
  results.accountSignedIn = {
    has_h1: (await page.locator("h1").first().textContent())?.trim().slice(0, 80) ?? "",
    section_count: await page.locator("section").count(),
  };
}

results.console_errors = consoleErrors;
console.log(JSON.stringify(results, null, 2));
await browser.close();
